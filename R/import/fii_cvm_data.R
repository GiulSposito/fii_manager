# fii_cvm_data.R
# CVM Open Data collector for FII fundamental indicators
# Downloads monthly reports (inf_mensal) from CVM and extracts key metrics
#
# Data available: patrimônio líquido, valor patrimonial por cota, DY,
# rentabilidade, cotistas, segmento, taxas
# Data NOT available: vacância (use StatusInvest for this)
#
# Source: https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/
# Format: CSV (Windows-1252 encoding), semicolon-delimited
# Free access, no authentication required

library(dplyr)
library(readr)
library(tidyr)
library(stringr)
library(glue)
library(lubridate)
library(httr2)

source("R/utils/http_client.R")
source("R/utils/logging.R")
source("R/utils/persistence.R")
source("R/utils/brazilian_parsers.R")
source("R/collectors/collector_base.R")

#' Create CVM Collector
#'
#' Creates a collector instance for CVM monthly FII data.
#' Follows collector_base.R pattern with standard interface.
#'
#' @param config List with configuration
#'   - base_url: CVM data URL (default: https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/)
#'   - cache_dir: Directory for CSV cache (default: data/.cache/cvm)
#'   - cache_ttl_days: Cache TTL in days (default: 30)
#'   - data$portfolio_file: Path to portfolio.rds for ticker list
#'   - output: Output filename (default: fii_cvm.rds)
#' @param logger Logger instance from logging.R
#' @return Collector instance with $collect() method
#' @export
create_cvm_collector <- function(config, logger) {
  collect_fn <- function(config, logger) {
    # Get portfolio tickers
    portfolio_file <- config$data$portfolio_file %||% "./data/portfolio.rds"
    if (!file.exists(portfolio_file)) {
      return(create_result(
        success = FALSE,
        error = "Portfolio file not found - cannot determine tickers"
      ))
    }

    portfolio <- readRDS(portfolio_file)
    tickers <- unique(portfolio$ticker)

    # Get CNPJ mapping
    mapping <- build_cnpj_ticker_mapping(logger)
    if (nrow(mapping) == 0) {
      return(create_result(
        success = FALSE,
        error = "Failed to build CNPJ-ticker mapping"
      ))
    }

    # Filter tickers that have CNPJ mapping
    tickers_with_cnpj <- tickers[tickers %in% mapping$ticker]

    if (length(tickers_with_cnpj) == 0) {
      return(create_result(
        success = FALSE,
        error = "No portfolio tickers have CNPJ mapping"
      ))
    }

    logger$info(glue("Found CNPJ mapping for {length(tickers_with_cnpj)}/{length(tickers)} portfolio tickers"))

    # Collect data
    collect_cvm_data(
      tickers = tickers_with_cnpj,
      mapping = mapping,
      config = config,
      logger = logger
    )
  }

  create_base_collector(
    name = "cvm_data",
    config = config,
    logger = logger,
    collect_fn = collect_fn
  )
}

#' Coalesce NULL Helper
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Collect CVM Data for FIIs
#'
#' Main collection function that orchestrates download, parse, and merge.
#'
#' @param tickers Character vector of FII tickers
#' @param mapping Tibble with ticker and cnpj columns
#' @param config List with configuration
#' @param logger Logger instance
#' @return Standard collector result list
#' @keywords internal
collect_cvm_data <- function(tickers, mapping, config, logger) {
  start_time <- Sys.time()

  result <- list(
    success = FALSE,
    data = NULL,
    metadata = list(
      source = "cvm_data",
      collected_at = Sys.time(),
      tickers_total = length(tickers),
      tickers_success = 0,
      tickers_failed = 0,
      rows = 0
    ),
    error = NULL
  )

  tryCatch({
    # Configuration
    base_url <- config$base_url %||% "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/"
    cache_dir <- config$cache_dir %||% "data/.cache/cvm"
    cache_ttl_days <- config$cache_ttl_days %||% 30

    # Create cache directory
    if (!dir.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE)
      logger$info(glue("Created cache directory: {cache_dir}"))
    }

    # Download data for current year and previous year (for historical data)
    current_year <- year(today())
    years <- c(current_year, current_year - 1)

    all_cvm_data <- list()

    for (yr in years) {
      logger$info(glue("Processing CVM data for year {yr}"))

      cvm_data <- fetch_cvm_monthly_data(
        year = yr,
        base_url = base_url,
        cache_dir = cache_dir,
        cache_ttl_days = cache_ttl_days,
        logger = logger
      )

      if (!is.null(cvm_data)) {
        all_cvm_data[[as.character(yr)]] <- cvm_data
      } else {
        logger$warn(glue("No data retrieved for year {yr}"))
      }
    }

    if (length(all_cvm_data) == 0) {
      stop("Failed to download CVM data for any year")
    }

    # Combine all years
    combined_data <- bind_rows(all_cvm_data)
    logger$info(glue("Combined data: {nrow(combined_data)} total rows"))

    # Extract indicators for portfolio tickers
    cnpjs <- mapping %>%
      filter(ticker %in% tickers) %>%
      pull(cnpj)

    logger$info(glue("Extracting data for {length(cnpjs)} CNPJs"))

    indicators <- extract_fii_indicators(
      cvm_data = combined_data,
      mapping = mapping,
      logger = logger
    )

    if (nrow(indicators) == 0) {
      stop("No indicators extracted from CVM data")
    }

    logger$info(glue("Extracted {nrow(indicators)} indicator records"))

    # Save with incremental merge
    output_path <- file.path("data", config$output %||% "fii_cvm.rds")
    existing <- load_rds_safe(output_path, default = NULL, logger = logger)

    if (!is.null(existing)) {
      # Merge: keep newer data for same ticker+date
      indicators_final <- merge_incremental(
        new_data = indicators,
        existing_data = existing,
        dedup_columns = c("ticker", "data_competencia"),
        logger = logger
      )
    } else {
      indicators_final <- indicators
    }

    # Save with backup
    save_rds_with_backup(
      indicators_final,
      output_path,
      backup_dir = "data_backup",
      logger = logger
    )

    # Count success/failure
    tickers_found <- unique(indicators$ticker)
    tickers_missing <- setdiff(tickers, tickers_found)

    # Result
    result$success <- TRUE
    result$data <- indicators_final
    result$metadata$tickers_success <- length(tickers_found)
    result$metadata$tickers_failed <- length(tickers_missing)
    result$metadata$rows <- nrow(indicators_final)
    result$metadata$duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    result$metadata$failed_tickers <- tickers_missing
    result$metadata$years_processed <- years

    if (length(tickers_missing) > 0) {
      logger$warn(glue("Missing data for {length(tickers_missing)} tickers: {paste(tickers_missing, collapse=', ')}"))
    }

    logger$info(glue("Collection completed in {round(result$metadata$duration_secs, 2)}s"))

    result

  }, error = function(e) {
    logger$error(glue("Collection failed: {e$message}"))
    result$error <- e$message
    result$metadata$duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    result
  })
}

#' Fetch CVM Monthly Data for Year
#'
#' Downloads and parses CVM monthly reports for a specific year.
#' Uses cache to avoid repeated downloads.
#'
#' @param year Integer year (e.g., 2026)
#' @param base_url Character, CVM base URL
#' @param cache_dir Character, cache directory path
#' @param cache_ttl_days Integer, cache TTL in days
#' @param logger Logger instance
#' @return Tibble with parsed CVM data or NULL on error
#' @keywords internal
fetch_cvm_monthly_data <- function(year, base_url, cache_dir, cache_ttl_days, logger) {
  zip_filename <- glue("inf_mensal_fii_{year}.zip")
  zip_path <- file.path(cache_dir, zip_filename)
  extract_dir <- file.path(cache_dir, glue("cvm_fii_{year}"))

  # Check cache validity
  use_cache <- FALSE
  if (file.exists(zip_path)) {
    file_age_days <- as.numeric(difftime(Sys.time(), file.mtime(zip_path), units = "days"))
    use_cache <- file_age_days < cache_ttl_days

    if (use_cache) {
      logger$info(glue("Using cached file: {zip_filename} (age: {round(file_age_days, 1)} days)"))
    } else {
      logger$info(glue("Cache expired for {zip_filename} (age: {round(file_age_days, 1)} days, TTL: {cache_ttl_days} days)"))
    }
  }

  # Download if not cached or expired
  if (!use_cache) {
    logger$info(glue("Downloading {zip_filename}..."))

    download_success <- download_cvm_zip(
      year = year,
      base_url = base_url,
      zip_path = zip_path,
      logger = logger
    )

    if (!download_success) {
      return(NULL)
    }
  }

  # Extract ZIP if needed
  if (!dir.exists(extract_dir) || length(list.files(extract_dir)) == 0) {
    logger$info(glue("Extracting {zip_filename}..."))

    tryCatch({
      if (dir.exists(extract_dir)) unlink(extract_dir, recursive = TRUE)
      dir.create(extract_dir, showWarnings = FALSE)
      unzip(zip_path, exdir = extract_dir)
      logger$info(glue("Extracted to {extract_dir}"))
    }, error = function(e) {
      logger$error(glue("Failed to extract {zip_filename}: {e$message}"))
      return(NULL)
    })
  }

  # Parse CSV files
  cvm_data <- parse_cvm_csv(
    extract_dir = extract_dir,
    year = year,
    logger = logger
  )

  cvm_data
}

#' Download CVM ZIP File
#'
#' Downloads CVM monthly report ZIP file with retry logic.
#'
#' @param year Integer year
#' @param base_url Character, CVM base URL
#' @param zip_path Character, local path to save ZIP
#' @param logger Logger instance
#' @return Logical, TRUE if successful
#' @keywords internal
download_cvm_zip <- function(year, base_url, zip_path, logger) {
  zip_filename <- basename(zip_path)
  zip_url <- glue("{base_url}{zip_filename}")

  # Create HTTP client with retry
  http_config <- list(
    base_url = "",
    timeout_seconds = 60,
    retry = list(max_attempts = 3, backoff_factor = 2),
    rate_limit = list(delay_between_requests = 1.0)
  )

  client <- create_http_client(http_config, logger)

  tryCatch({
    resp <- client$get(zip_url)

    if (!is_response_success(resp)) {
      logger$error(glue("Failed to download {zip_filename}: HTTP {httr2::resp_status(resp)}"))
      return(FALSE)
    }

    # Save ZIP
    writeBin(httr2::resp_body_raw(resp), zip_path)
    file_size_kb <- round(file.size(zip_path) / 1024, 1)
    logger$info(glue("Downloaded {zip_filename} ({file_size_kb} KB)"))

    TRUE

  }, error = function(e) {
    logger$error(glue("Error downloading {zip_filename}: {e$message}"))
    FALSE
  })
}

#' Parse CVM CSV Files
#'
#' Reads and parses CVM monthly report CSV files (geral, complemento, ativo_passivo).
#' Joins the datasets to create comprehensive indicator records.
#'
#' @param extract_dir Character, directory with extracted CSVs
#' @param year Integer year
#' @param logger Logger instance
#' @return Tibble with parsed data
#' @keywords internal
parse_cvm_csv <- function(extract_dir, year, logger) {
  # File paths
  geral_path <- file.path(extract_dir, glue("inf_mensal_fii_geral_{year}.csv"))
  complemento_path <- file.path(extract_dir, glue("inf_mensal_fii_complemento_{year}.csv"))

  # Read geral (main data)
  if (!file.exists(geral_path)) {
    logger$error(glue("File not found: {geral_path}"))
    return(tibble())
  }

  logger$debug(glue("Reading {basename(geral_path)}"))

  geral <- tryCatch({
    read_delim(
      geral_path,
      delim = ";",
      locale = locale(
        encoding = "Windows-1252",
        decimal_mark = ".",
        grouping_mark = ""
      ),
      col_types = cols(.default = col_character()),
      show_col_types = FALSE
    )
  }, error = function(e) {
    logger$error(glue("Failed to read geral CSV: {e$message}"))
    return(tibble())
  })

  if (nrow(geral) == 0) {
    return(tibble())
  }

  logger$info(glue("Read geral: {nrow(geral)} rows, {ncol(geral)} columns"))

  # Read complemento (supplementary data)
  complemento <- NULL
  if (file.exists(complemento_path)) {
    logger$debug(glue("Reading {basename(complemento_path)}"))

    complemento <- tryCatch({
      read_delim(
        complemento_path,
        delim = ";",
        locale = locale(
          encoding = "Windows-1252",
          decimal_mark = ".",
          grouping_mark = ""
        ),
        col_types = cols(.default = col_character()),
        show_col_types = FALSE
      )
    }, error = function(e) {
      logger$warn(glue("Failed to read complemento CSV: {e$message}"))
      NULL
    })

    if (!is.null(complemento)) {
      logger$info(glue("Read complemento: {nrow(complemento)} rows, {ncol(complemento)} columns"))
    }
  }

  # Join datasets
  if (!is.null(complemento)) {
    result <- geral %>%
      left_join(
        complemento,
        by = c("CNPJ_Fundo_Classe", "Data_Referencia", "Versao"),
        suffix = c("_geral", "_compl")
      )

    logger$debug(glue("Joined geral + complemento: {nrow(result)} rows"))
  } else {
    result <- geral
  }

  result
}

#' Extract FII Indicators from CVM Data
#'
#' Filters CVM data by portfolio FIIs and extracts key indicators.
#' Returns one row per ticker per month with latest available data.
#'
#' @param cvm_data Tibble with raw CVM data
#' @param mapping Tibble with ticker and cnpj columns
#' @param logger Logger instance
#' @return Tibble with indicators (ticker, data_competencia, metrics)
#' @keywords internal
extract_fii_indicators <- function(cvm_data, mapping, logger) {
  if (nrow(cvm_data) == 0) {
    logger$warn("Empty CVM data")
    return(tibble())
  }

  # Get CNPJs to filter
  cnpj_list <- mapping$cnpj

  # Filter by CNPJ
  filtered <- cvm_data %>%
    filter(CNPJ_Fundo_Classe %in% cnpj_list)

  if (nrow(filtered) == 0) {
    logger$warn("No matching CNPJs found in CVM data")
    return(tibble())
  }

  logger$debug(glue("Filtered to {nrow(filtered)} rows for portfolio CNPJs"))

  # Parse and select key fields
  indicators <- filtered %>%
    mutate(
      data_competencia = ymd(Data_Referencia),
      cnpj = CNPJ_Fundo_Classe
    ) %>%
    # Latest version per CNPJ per date
    arrange(cnpj, data_competencia, desc(as.numeric(Versao))) %>%
    group_by(cnpj, data_competencia) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    # Select and parse fields
    transmute(
      cnpj = cnpj,
      data_competencia = data_competencia,
      nome_fundo = Nome_Fundo_Classe,
      segmento = Segmento_Atuacao,

      # Numeric fields - parse as numeric
      patrimonio_liquido = as.numeric(Patrimonio_Liquido),
      valor_patrimonial_cota = as.numeric(Valor_Patrimonial_Cotas),

      # Percentage fields - parse as percentage (multiply by 100 for human readable)
      dividend_yield = as.numeric(Percentual_Dividend_Yield_Mes),
      rentabilidade_mensal = as.numeric(Percentual_Rentabilidade_Efetiva_Mes),

      # Count fields
      numero_cotistas = as.numeric(Total_Numero_Cotistas),

      # Fee fields (if available)
      tx_administracao = if ("Taxa_Administracao" %in% names(filtered)) as.numeric(Taxa_Administracao) else NA_real_,
      tx_performance = if ("Taxa_Performance" %in% names(filtered)) as.numeric(Taxa_Performance) else NA_real_
    )

  # Join with mapping to add tickers
  indicators_with_ticker <- indicators %>%
    inner_join(mapping, by = "cnpj") %>%
    select(ticker, data_competencia, everything(), -cnpj)

  logger$info(glue("Extracted indicators for {n_distinct(indicators_with_ticker$ticker)} unique tickers"))

  indicators_with_ticker
}

#' Build CNPJ-Ticker Mapping
#'
#' Creates or loads a mapping table between CNPJ and ticker.
#' Uses multiple sources: existing mapping file, fii_info.rds, StatusInvest scraping.
#'
#' @param logger Logger instance
#' @return Tibble with ticker and cnpj columns
#' @keywords internal
build_cnpj_ticker_mapping <- function(logger) {
  mapping_file <- "data/fii_cnpj_mapping.rds"

  # Try to load existing mapping
  if (file.exists(mapping_file)) {
    mapping <- readRDS(mapping_file)

    # Check if mapping is recent (less than 90 days old)
    file_age_days <- as.numeric(difftime(Sys.time(), file.mtime(mapping_file), units = "days"))

    if (file_age_days < 90 && nrow(mapping) > 0) {
      logger$info(glue("Using cached CNPJ mapping: {nrow(mapping)} entries (age: {round(file_age_days, 1)} days)"))
      return(mapping)
    } else {
      logger$info(glue("CNPJ mapping cache expired (age: {round(file_age_days, 1)} days) - rebuilding"))
    }
  }

  # Build new mapping
  logger$info("Building CNPJ-ticker mapping from available sources")

  mapping_sources <- list()

  # Source 1: fii_info.rds (if available)
  if (file.exists("data/fii_info.rds")) {
    fii_info <- readRDS("data/fii_info.rds")

    if ("cnpj" %in% names(fii_info) && "ticker" %in% names(fii_info)) {
      mapping_sources$fii_info <- fii_info %>%
        select(ticker, cnpj) %>%
        filter(!is.na(cnpj), cnpj != "")

      logger$info(glue("Found {nrow(mapping_sources$fii_info)} mappings from fii_info.rds"))
    }
  }

  # Source 2: fii_lupa.rds (may contain CNPJ)
  if (file.exists("data/fii_lupa.rds")) {
    fii_lupa <- readRDS("data/fii_lupa.rds")

    if ("cnpj" %in% names(fii_lupa) && "ticker" %in% names(fii_lupa)) {
      mapping_sources$fii_lupa <- fii_lupa %>%
        select(ticker, cnpj) %>%
        filter(!is.na(cnpj), cnpj != "")

      logger$info(glue("Found {nrow(mapping_sources$fii_lupa)} mappings from fii_lupa.rds"))
    }
  }

  # Source 3: Hardcoded known mappings (from test_cvm_api.R validation)
  mapping_sources$known <- tibble::tribble(
    ~ticker,   ~cnpj,
    "KNRI11",  "12.005.956/0001-65",
    "MXRF11",  "08.706.065/0001-69",
    "VISC11",  "12.516.185/0001-70"
  )

  logger$info(glue("Added {nrow(mapping_sources$known)} known hardcoded mappings"))

  # Combine all sources
  if (length(mapping_sources) == 0) {
    logger$warn("No CNPJ mapping sources available")
    return(tibble(ticker = character(), cnpj = character()))
  }

  mapping <- bind_rows(mapping_sources) %>%
    distinct(ticker, cnpj, .keep_all = TRUE) %>%
    filter(!is.na(cnpj), cnpj != "") %>%
    arrange(ticker)

  logger$info(glue("Built CNPJ mapping: {nrow(mapping)} unique ticker-CNPJ pairs"))

  # Save mapping for future use
  tryCatch({
    saveRDS(mapping, mapping_file)
    logger$info(glue("Saved CNPJ mapping to {mapping_file}"))
  }, error = function(e) {
    logger$warn(glue("Failed to save CNPJ mapping: {e$message}"))
  })

  mapping
}

#' Get FII CVM History
#'
#' Retrieves historical CVM data for a specific FII ticker.
#' Convenience function for analysis scripts.
#'
#' @param ticker Character, FII ticker (e.g., "ALZR11")
#' @param months Integer, number of months of history to retrieve
#' @param cvm_file Character, path to fii_cvm.rds file
#' @return Tibble with historical data for the ticker
#' @export
get_fii_cvm_history <- function(ticker, months = 12, cvm_file = "data/fii_cvm.rds") {
  if (!file.exists(cvm_file)) {
    warning(glue("CVM data file not found: {cvm_file}"))
    return(tibble())
  }

  cvm_data <- readRDS(cvm_file)

  cutoff_date <- today() - months(months)

  cvm_data %>%
    filter(
      ticker == !!ticker,
      data_competencia >= cutoff_date
    ) %>%
    arrange(desc(data_competencia))
}

#' Validate CVM Data Schema
#'
#' Validates that CVM data has expected structure.
#'
#' @param data Tibble with CVM data
#' @param logger Logger instance (optional)
#' @return Logical, TRUE if valid
#' @keywords internal
validate_cvm_schema <- function(data, logger = NULL) {
  required_cols <- c(
    "ticker",
    "data_competencia",
    "nome_fundo",
    "segmento",
    "patrimonio_liquido",
    "valor_patrimonial_cota"
  )

  missing <- setdiff(required_cols, names(data))

  if (length(missing) > 0) {
    if (!is.null(logger)) {
      logger$error(glue("Missing required columns: {paste(missing, collapse=', ')}"))
    }
    return(FALSE)
  }

  # Check for data
  if (nrow(data) == 0) {
    if (!is.null(logger)) {
      logger$warn("CVM data is empty")
    }
    return(FALSE)
  }

  if (!is.null(logger)) {
    logger$debug("CVM schema validation passed")
  }

  TRUE
}
