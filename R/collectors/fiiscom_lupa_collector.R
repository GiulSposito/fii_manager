# fiiscom_lupa_collector.R
# Coletor para fiis.com.br Lupa API - Metadata completa de FIIs
# Extrai 22 colunas de metadados fundamentalistas via POST request

library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(glue)

source("R/utils/logging.R")
source("R/utils/http_client.R")
source("R/utils/brazilian_parsers.R")
source("R/utils/persistence.R")

#' Collect FII Metadata from fiis.com.br Lupa API
#'
#' Fetches comprehensive FII metadata via POST request to Lupa API.
#' Requires authentication via cookies and nonce from environment variables.
#' Implements cache fallback with 7-day TTL for graceful degradation.
#'
#' @param config List with collector configuration from pipeline_config.yaml
#' @param logger Logger instance (optional)
#' @param force_refresh Logical, bypass cache (default FALSE)
#' @return List with success, data, metadata, and error (if any)
#' @export
collect_fiiscom_lupa <- function(config, logger = NULL, force_refresh = FALSE) {
  start_time <- Sys.time()

  if (!is.null(logger)) {
    logger$info("Starting fiis.com.br Lupa API collection")
  }

  result <- list(
    success = FALSE,
    data = NULL,
    metadata = list(
      source = "fiiscom_lupa",
      collected_at = Sys.time(),
      rows = 0,
      cache_used = FALSE,
      auth_expired = FALSE
    ),
    error = NULL
  )

  tryCatch({
    # Verifica cache primeiro
    if (!force_refresh && config$cache_ttl_hours > 0) {
      cached <- try_load_cache(config$output, config$cache_ttl_hours, logger)
      if (!is.null(cached)) {
        if (!is.null(logger)) {
          logger$info(glue("Using cached data ({nrow(cached)} rows, age < {config$cache_ttl_hours}h)"))
        }
        result$success <- TRUE
        result$data <- cached
        result$metadata$rows <- nrow(cached)
        result$metadata$cache_used <- TRUE
        return(result)
      }
    }

    # Obter credenciais de autenticação
    cookie <- Sys.getenv(config$auth$cookie_env_var, "")
    nonce <- Sys.getenv(config$auth$nonce_env_var, "")

    if (cookie == "" || nonce == "") {
      warning_msg <- glue("Auth credentials not found in environment variables: {config$auth$cookie_env_var}, {config$auth$nonce_env_var}")

      if (!is.null(logger)) {
        logger$warn(warning_msg)
        logger$info("Attempting to use cached data (any age)...")
      }

      # Tenta cache de qualquer idade como fallback
      cached_fallback <- load_rds_safe(
        file.path("data", config$output),
        default = NULL,
        logger = logger
      )

      if (!is.null(cached_fallback)) {
        if (!is.null(logger)) {
          logger$info(glue("Using stale cache as fallback ({nrow(cached_fallback)} rows)"))
        }
        result$success <- TRUE
        result$data <- cached_fallback
        result$metadata$rows <- nrow(cached_fallback)
        result$metadata$cache_used <- TRUE
        result$metadata$auth_expired <- TRUE
        return(result)
      }

      stop("No auth credentials and no cached data available")
    }

    # Criar HTTP client
    http_config <- list(
      base_url = config$base_url,
      timeout_seconds = config$timeout_seconds,
      rate_limit = config$rate_limit,
      retry = config$retry,
      user_agent = "fiiscrapeR/2.0 (Lupa Collector)"
    )

    client <- create_http_client(http_config, logger)

    # Headers com autenticação
    headers <- list(
      "authority" = "fiis.com.br",
      "accept" = "application/json, text/plain, */*",
      "accept-language" = "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
      "cookie" = cookie,
      "referer" = "https://fiis.com.br/lupa-de-fiis/",
      "sec-ch-ua" = '"Not.A/Brand";v="8", "Chromium";v="114"',
      "sec-ch-ua-mobile" = "?0",
      "sec-ch-ua-platform" = '"macOS"',
      "sec-fetch-dest" = "empty",
      "sec-fetch-mode" = "cors",
      "sec-fetch-site" = "same-origin",
      "x-fiis-nonce" = nonce
    )

    # Fazer POST request
    if (!is.null(logger)) {
      logger$debug(glue("POST {config$base_url}"))
    }

    resp <- client$post(
      config$base_url,
      headers = headers,
      body = NULL
    )

    # Verificar autenticação
    if (is_auth_error(resp)) {
      if (!is.null(logger)) {
        logger$warn("Authentication failed (401/403) - trying stale cache")
      }

      cached_fallback <- load_rds_safe(
        file.path("data", config$output),
        default = NULL,
        logger = logger
      )

      if (!is.null(cached_fallback)) {
        result$success <- TRUE
        result$data <- cached_fallback
        result$metadata$rows <- nrow(cached_fallback)
        result$metadata$cache_used <- TRUE
        result$metadata$auth_expired <- TRUE
        return(result)
      }

      stop("Authentication failed and no cache available")
    }

    # Parse response
    if (!is.null(logger)) {
      logger$debug("Parsing JSON response")
    }

    raw_json <- resp_body_string(resp)

    # Double parse (JSON dentro de JSON, baseado no código original)
    fii_data <- raw_json %>%
      fromJSON() %>%
      fromJSON() %>%
      as_tibble()

    # Transform data types
    fii_data <- fii_data %>%
      mutate(
        # Remove pontos de milhares em 'negocios'
        negocios = str_remove_all(negocios, "\\."),

        # Converte IDs e contadores para integer
        across(
          c(id, post_id, last_dividend, negocios, numero_cotista),
          as.integer
        ),

        # Converte métricas numéricas
        across(
          c(
            dy,
            starts_with("rendimento"),
            patrimonio_cota,
            cota_base,
            cota_vp,
            participacao_ifix,
            patrimonio
          ),
          as.numeric
        ),

        # Converte flag booleana
        last_dividend = as.logical(last_dividend),

        # Converte datas
        across(c(data_pagamento, data_base), ymd),

        # Adiciona timestamp de coleta
        collected_at = Sys.time()
      )

    # Validação básica
    if (nrow(fii_data) == 0) {
      stop("API returned empty dataset")
    }

    if (!is.null(logger)) {
      logger$info(glue("Collected {nrow(fii_data)} FIIs with {ncol(fii_data)} columns"))
    }

    # Salvar com backup
    output_path <- file.path("data", config$output)
    save_rds_with_backup(
      fii_data,
      output_path,
      backup_dir = "data_backup",
      logger = logger
    )

    # Resultado final
    result$success <- TRUE
    result$data <- fii_data
    result$metadata$rows <- nrow(fii_data)
    result$metadata$duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

    if (!is.null(logger)) {
      logger$info(glue("Collection completed successfully in {round(result$metadata$duration_secs, 2)}s"))
    }

    result

  }, error = function(e) {
    if (!is.null(logger)) {
      logger$error(glue("Collection failed: {e$message}"))
    }

    result$error <- e$message
    result$metadata$duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    result
  })
}

#' Try Load Cache with TTL Check
#'
#' @param filename Character, RDS filename
#' @param ttl_hours Numeric, cache validity in hours
#' @param logger Logger instance (optional)
#' @return Data or NULL if cache invalid/missing
#' @keywords internal
try_load_cache <- function(filename, ttl_hours, logger = NULL) {
  filepath <- file.path("data", filename)

  if (!file.exists(filepath)) {
    return(NULL)
  }

  # Verifica idade do arquivo
  file_age_hours <- as.numeric(difftime(
    Sys.time(),
    file.info(filepath)$mtime,
    units = "hours"
  ))

  if (file_age_hours > ttl_hours) {
    if (!is.null(logger)) {
      logger$debug(glue("Cache expired: {round(file_age_hours, 1)}h > {ttl_hours}h TTL"))
    }
    return(NULL)
  }

  # Carrega cache válido
  tryCatch({
    data <- readRDS(filepath)
    if (!is.null(logger)) {
      logger$debug(glue("Cache valid: {round(file_age_hours, 1)}h old"))
    }
    data
  }, error = function(e) {
    if (!is.null(logger)) {
      logger$warn(glue("Cache read failed: {e$message}"))
    }
    NULL
  })
}

#' Import FII Ticker List from fiis.com.br
#'
#' Scrapes list of all available FII tickers from listing page.
#' Used as reference list for other collectors.
#'
#' @param logger Logger instance (optional)
#' @return Character vector of tickers (uppercase)
#' @export
import_fii_list <- function(logger = NULL) {
  if (!is.null(logger)) {
    logger$info("Fetching FII ticker list from fiis.com.br")
  }

  tryCatch({
    library(rvest)

    tickers <- read_html("https://fiis.com.br/lista-de-fundos-imobiliarios/") %>%
      html_elements("span.ticker") %>%
      html_text() %>%
      str_trim() %>%
      str_to_upper() %>%
      unique()

    if (!is.null(logger)) {
      logger$info(glue("Found {length(tickers)} tickers"))
    }

    tickers
  }, error = function(e) {
    if (!is.null(logger)) {
      logger$error(glue("Failed to fetch ticker list: {e$message}"))
    }
    character(0)
  })
}

#' Validate Lupa Data Schema
#'
#' @param data Tibble with Lupa data
#' @param logger Logger instance (optional)
#' @return Logical, TRUE if valid
#' @keywords internal
validate_lupa_schema <- function(data, logger = NULL) {
  required_cols <- c(
    "id", "post_id", "ticker", "dy", "rendimento_medio_12m",
    "patrimonio_cota", "cota_base", "cota_vp", "numero_cotista",
    "data_pagamento", "data_base"
  )

  missing <- setdiff(required_cols, names(data))

  if (length(missing) > 0) {
    if (!is.null(logger)) {
      logger$error(glue("Missing required columns: {paste(missing, collapse=', ')}"))
    }
    return(FALSE)
  }

  TRUE
}
