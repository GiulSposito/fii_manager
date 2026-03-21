# test_cvm_api.R
# Prototype to validate CVM Open Data for FII analysis
#
# Purpose: Test if we can access and parse structured data from CVM about FIIs
# Goal: Extract at least one indicator (e.g., VACÂNCIA) with >70% success rate

library(tidyverse)
library(httr2)
library(glue)
library(lubridate)

# Source HTTP client utilities
source("R/utils/http_client.R")

# =============================================================================
# Configuration
# =============================================================================

CVM_BASE_URL <- "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/"
CURRENT_YEAR <- year(today())

# Test FIIs with CNPJ mapping (discovered from CVM data exploration)
TEST_FIIS <- tibble::tribble(
  ~ticker,   ~cnpj,                ~fund_name_pattern,
  "HGLG11",  NA_character_,        "HECTARE",
  "KNRI11",  "12.005.956/0001-65", "KINEA RENDA IMOBILIARIA",
  "MXRF11",  "08.706.065/0001-69", "HOTEL MAXINVEST",
  "VISC11",  "12.516.185/0001-70", "VINCI OFFICES",
  "XPLG11",  NA_character_,        "XP LOG"
)

# =============================================================================
# HTTP Client Setup
# =============================================================================

create_cvm_client <- function() {
  config <- list(
    base_url = CVM_BASE_URL,
    timeout_seconds = 30,
    rate_limit = list(delay_between_requests = 1.0),
    retry = list(max_attempts = 3, backoff_factor = 2),
    user_agent = "fiiscrapeR/2.0 (R httr2)"
  )

  create_http_client(config)
}

# =============================================================================
# Data Download Functions
# =============================================================================

#' Download CVM monthly reports for a specific year
#'
#' @param year Integer year (e.g., 2026)
#' @param client HTTP client instance
#' @param temp_dir Directory to save files
#' @return Path to extracted CSV files directory or NULL on error
download_cvm_monthly_data <- function(year, client, temp_dir = tempdir()) {
  zip_filename <- glue("inf_mensal_fii_{year}.zip")
  zip_url <- glue("{CVM_BASE_URL}{zip_filename}")
  zip_path <- file.path(temp_dir, zip_filename)
  extract_dir <- file.path(temp_dir, glue("cvm_fii_{year}"))

  message(glue("Downloading {zip_filename}..."))

  tryCatch({
    # Download ZIP file
    resp <- client$get(zip_url)

    if (!is_response_success(resp)) {
      warning(glue("Failed to download {zip_filename}: HTTP {httr2::resp_status(resp)}"))
      return(NULL)
    }

    # Save ZIP file
    writeBin(httr2::resp_body_raw(resp), zip_path)
    message(glue("Downloaded {format(file.size(zip_path) / 1024, digits=1)} KB"))

    # Extract ZIP
    if (dir.exists(extract_dir)) unlink(extract_dir, recursive = TRUE)
    dir.create(extract_dir, showWarnings = FALSE)

    unzip(zip_path, exdir = extract_dir)
    message(glue("Extracted to {extract_dir}"))

    return(extract_dir)

  }, error = function(e) {
    warning(glue("Error downloading CVM data: {e$message}"))
    return(NULL)
  })
}

# =============================================================================
# Data Parsing Functions
# =============================================================================

#' Read CVM monthly report CSV files
#'
#' @param extract_dir Directory with extracted CSV files
#' @return List with geral, complemento, ativo_passivo dataframes
read_cvm_monthly_data <- function(extract_dir) {
  year <- str_extract(basename(extract_dir), "\\d{4}")

  files <- list(
    geral = glue("inf_mensal_fii_geral_{year}.csv"),
    complemento = glue("inf_mensal_fii_complemento_{year}.csv"),
    ativo_passivo = glue("inf_mensal_fii_ativo_passivo_{year}.csv")
  )

  result <- list()

  for (name in names(files)) {
    file_path <- file.path(extract_dir, files[[name]])

    if (!file.exists(file_path)) {
      warning(glue("File not found: {file_path}"))
      result[[name]] <- NULL
      next
    }

    tryCatch({
      # Read CSV with proper encoding (CVM uses Windows-1252)
      df <- read_delim(
        file_path,
        delim = ";",
        locale = locale(
          encoding = "Windows-1252",
          decimal_mark = ".",
          grouping_mark = ""
        ),
        col_types = cols(.default = col_character()),
        show_col_types = FALSE
      )

      message(glue("Read {name}: {nrow(df)} rows, {ncol(df)} columns"))
      result[[name]] <- df

    }, error = function(e) {
      warning(glue("Error reading {name}: {e$message}"))
      result[[name]] <- NULL
    })
  }

  return(result)
}

#' Extract latest data for specific FIIs by CNPJ
#'
#' @param cvm_data List with geral, complemento, ativo_passivo dataframes
#' @param cnpj_list Character vector of CNPJs to filter
#' @return Tibble with joined data for specified FIIs
extract_fii_data <- function(cvm_data, cnpj_list) {
  if (is.null(cvm_data$geral) || is.null(cvm_data$complemento)) {
    warning("Missing required CVM data (geral or complemento)")
    return(tibble())
  }

  # Filter by CNPJ
  geral <- cvm_data$geral %>%
    filter(CNPJ_Fundo_Classe %in% cnpj_list) %>%
    mutate(Data_Referencia = ymd(Data_Referencia)) %>%
    arrange(CNPJ_Fundo_Classe, desc(Data_Referencia)) %>%
    group_by(CNPJ_Fundo_Classe) %>%
    slice_head(n = 1) %>%
    ungroup()

  complemento <- cvm_data$complemento %>%
    filter(CNPJ_Fundo_Classe %in% cnpj_list) %>%
    mutate(Data_Referencia = ymd(Data_Referencia)) %>%
    arrange(CNPJ_Fundo_Classe, desc(Data_Referencia)) %>%
    group_by(CNPJ_Fundo_Classe) %>%
    slice_head(n = 1) %>%
    ungroup()

  # Join datasets
  result <- geral %>%
    left_join(
      complemento,
      by = c("CNPJ_Fundo_Classe", "Data_Referencia", "Versao"),
      suffix = c("_geral", "_compl")
    ) %>%
    select(
      cnpj = CNPJ_Fundo_Classe,
      data_referencia = Data_Referencia,
      nome_fundo = Nome_Fundo_Classe,
      segmento = Segmento_Atuacao,
      patrimonio_liquido = Patrimonio_Liquido,
      valor_patrimonial_cota = Valor_Patrimonial_Cotas,
      dividend_yield = Percentual_Dividend_Yield_Mes,
      rentabilidade_mensal = Percentual_Rentabilidade_Efetiva_Mes,
      numero_cotistas = Total_Numero_Cotistas
    )

  return(result)
}

# =============================================================================
# Analysis Functions
# =============================================================================

#' Calculate success rate for data extraction
#'
#' @param test_fiis Test FIIs tibble with ticker, cnpj
#' @param extracted_data Extracted data tibble with cnpj
#' @return List with success metrics
calculate_success_rate <- function(test_fiis, extracted_data) {
  # Only test FIIs where we have CNPJ
  test_fiis_with_cnpj <- test_fiis %>%
    filter(!is.na(cnpj))

  total_tests <- nrow(test_fiis_with_cnpj)

  if (total_tests == 0) {
    return(list(
      success_rate = 0,
      successful = 0,
      total = 0,
      details = "No test FIIs with known CNPJ"
    ))
  }

  # Check which FIIs were found
  found_cnpjs <- extracted_data$cnpj
  test_cnpjs <- test_fiis_with_cnpj$cnpj

  successful <- sum(test_cnpjs %in% found_cnpjs)
  success_rate <- successful / total_tests

  # Detailed results
  test_results <- test_fiis_with_cnpj %>%
    mutate(
      found = cnpj %in% found_cnpjs,
      status = if_else(found, "SUCCESS", "NOT FOUND")
    )

  return(list(
    success_rate = success_rate,
    successful = successful,
    total = total_tests,
    details = test_results
  ))
}

#' Evaluate data quality (completeness of key fields)
#'
#' @param extracted_data Extracted data tibble
#' @return List with quality metrics
evaluate_data_quality <- function(extracted_data) {
  if (nrow(extracted_data) == 0) {
    return(list(
      completeness_rate = 0,
      fields_available = character(0),
      fields_missing = character(0)
    ))
  }

  # Key fields to check
  key_fields <- c(
    "patrimonio_liquido",
    "valor_patrimonial_cota",
    "dividend_yield",
    "numero_cotistas"
  )

  completeness <- extracted_data %>%
    summarise(across(
      all_of(key_fields),
      ~mean(!is.na(.) & . != ""),
      .names = "{.col}_complete"
    ))

  field_completeness <- completeness %>%
    pivot_longer(everything(), names_to = "field", values_to = "completeness") %>%
    mutate(field = str_remove(field, "_complete"))

  avg_completeness <- mean(field_completeness$completeness)

  fields_available <- field_completeness %>%
    filter(completeness > 0.5) %>%
    pull(field)

  fields_missing <- field_completeness %>%
    filter(completeness <= 0.5) %>%
    pull(field)

  return(list(
    completeness_rate = avg_completeness,
    field_details = field_completeness,
    fields_available = fields_available,
    fields_missing = fields_missing
  ))
}

# =============================================================================
# Main Test Function
# =============================================================================

#' Run CVM API validation test
#'
#' @return List with test results and recommendations
run_cvm_validation_test <- function() {
  message(paste0(strrep("=", 80)))
  message("CVM API VALIDATION TEST")
  message(paste0(strrep("=", 80)))
  message("")

  # Initialize HTTP client
  client <- create_cvm_client()
  message("HTTP client initialized")
  message("")

  # Download current year data
  message("STEP 1: Download CVM data")
  message(paste0(strrep("-", 80)))
  extract_dir <- download_cvm_monthly_data(CURRENT_YEAR, client)

  if (is.null(extract_dir)) {
    return(list(
      status = "FAILED",
      reason = "Could not download CVM data",
      recommendation = "NO-GO: CVM data not accessible"
    ))
  }
  message("")

  # Read data
  message("STEP 2: Parse CVM data")
  message(paste0(strrep("-", 80)))
  cvm_data <- read_cvm_monthly_data(extract_dir)

  if (is.null(cvm_data$geral)) {
    return(list(
      status = "FAILED",
      reason = "Could not parse CVM data",
      recommendation = "NO-GO: CVM data format changed or corrupted"
    ))
  }
  message("")

  # Extract test FII data
  message("STEP 3: Extract test FII data")
  message(paste0(strrep("-", 80)))

  test_cnpjs <- TEST_FIIS %>%
    filter(!is.na(cnpj)) %>%
    pull(cnpj)

  message(glue("Testing {length(test_cnpjs)} FIIs with known CNPJ"))

  extracted_data <- extract_fii_data(cvm_data, test_cnpjs)

  message(glue("Extracted data for {nrow(extracted_data)} FIIs"))
  message("")

  # Calculate success rate
  message("STEP 4: Calculate success metrics")
  message(paste0(strrep("-", 80)))

  success_metrics <- calculate_success_rate(TEST_FIIS, extracted_data)
  quality_metrics <- evaluate_data_quality(extracted_data)

  message(glue("Success rate: {round(success_metrics$success_rate * 100, 1)}%"))
  message(glue("  - Found: {success_metrics$successful}/{success_metrics$total}"))
  message("")
  message(glue("Data completeness: {round(quality_metrics$completeness_rate * 100, 1)}%"))
  message(glue("  - Available fields: {paste(quality_metrics$fields_available, collapse=', ')}"))
  if (length(quality_metrics$fields_missing) > 0) {
    message(glue("  - Incomplete fields: {paste(quality_metrics$fields_missing, collapse=', ')}"))
  }
  message("")

  # Display extracted data sample
  if (nrow(extracted_data) > 0) {
    message("Sample data:")
    print(extracted_data, n = 5)
    message("")
  }

  # Determine recommendation
  message(paste0(strrep("=", 80)))
  message("RESULTS & RECOMMENDATION")
  message(paste0(strrep("=", 80)))
  message("")

  # Check for vacancy data (the original goal)
  has_vacancy <- FALSE  # CVM data does NOT include vacancy

  if (success_metrics$success_rate >= 0.7 && quality_metrics$completeness_rate >= 0.7) {
    status <- "GO"
    recommendation <- "CVM data is viable for basic FII indicators"

    if (!has_vacancy) {
      recommendation <- paste0(
        recommendation,
        "\n  WARNING: Vacancy (VACÂNCIA) data NOT available in CVM monthly reports.",
        "\n  Consider: StatusInvest scraping or manual entry for vacancy metrics."
      )
    }
  } else {
    status <- "NO-GO"

    if (success_metrics$success_rate < 0.7) {
      recommendation <- glue(
        "CVM data has low success rate ({round(success_metrics$success_rate*100,1)}%)\n",
        "  Issue: Cannot reliably match FII tickers to CNPJ.\n",
        "  Alternative: Build CNPJ mapping table or use StatusInvest API."
      )
    } else {
      recommendation <- glue(
        "CVM data has low completeness ({round(quality_metrics$completeness_rate*100,1)}%)\n",
        "  Issue: Many required fields are missing.\n",
        "  Alternative: Use multiple data sources (CVM + StatusInvest)."
      )
    }
  }

  message(glue("Status: {status}"))
  message("")
  message("Recommendation:")
  message(recommendation)
  message("")

  # Return structured result
  return(list(
    status = status,
    success_rate = success_metrics$success_rate,
    data_completeness = quality_metrics$completeness_rate,
    successful_extractions = success_metrics$successful,
    total_tests = success_metrics$total,
    has_vacancy_data = has_vacancy,
    available_fields = quality_metrics$fields_available,
    missing_fields = quality_metrics$fields_missing,
    test_details = success_metrics$details,
    sample_data = extracted_data,
    recommendation = recommendation,
    notes = c(
      "CVM provides: Fund details, patrimony, segment, performance metrics",
      "CVM does NOT provide: Vacancy rates, detailed property info",
      "CNPJ-to-ticker mapping required for integration",
      "Data updated monthly with ~2 week delay",
      "Free access, no authentication required",
      "Rate limiting recommended: 1 req/sec"
    )
  ))
}

# =============================================================================
# Execute Test
# =============================================================================

if (!interactive()) {
  result <- run_cvm_validation_test()

  # Save result
  output_file <- "R/_draft/cvm_validation_result.rds"
  saveRDS(result, output_file)
  message(glue("Results saved to {output_file}"))

  # Exit with appropriate code
  if (result$status == "GO") {
    quit(status = 0)
  } else {
    quit(status = 1)
  }
}

# For interactive testing:
# result <- run_cvm_validation_test()
# View(result$sample_data)
# result$recommendation
