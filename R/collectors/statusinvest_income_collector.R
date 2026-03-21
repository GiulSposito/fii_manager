# statusinvest_income_collector.R
# Status Invest income API collector - 60x performance improvement
# Batch API request for all FII income distributions

library(httr2)
library(dplyr)
library(tidyr)
library(glue)

# Importa dependências
source("R/utils/http_client.R")
source("R/utils/brazilian_parsers.R")
source("R/utils/persistence.R")
source("R/collectors/collector_base.R")

#' Create Status Invest Income Collector
#'
#' Creates a collector for FII income distributions from Status Invest API.
#' Uses batch API request to fetch all tickers at once - 60x faster than
#' individual requests.
#'
#' @param config List with configuration (must contain api.statusinvest)
#' @param logger Logger instance
#' @return Collector instance
#' @export
create_statusinvest_income_collector <- function(config, logger) {

  # Função interna de coleta
  collect_fn <- function(config, logger) {
    tryCatch({
      # Config is the source-specific config from data_sources.statusinvest_income
      base_url <- config$base_url %||% "https://statusinvest.com.br/fii/getearnings"

      # Data range - último ano por padrão
      end_date <- Sys.Date()
      start_date <- config$income_start_date %||% (end_date - 365)

      logger$info(glue("Fetching income data from {start_date} to {end_date}"))

      # URL já está completa no config
      url <- base_url

      # Parâmetros da query
      # Usa IndiceCode=ifix para pegar todos os FIIs, Filter vazio
      query_params <- list(
        IndiceCode = "ifix",
        Filter = "",
        Start = format(start_date, "%Y-%m-%d"),
        End = format(end_date, "%Y-%m-%d")
      )

      logger$debug(glue("GET {url}?IndiceCode=ifix&Start={query_params$Start}&End={query_params$End}"))

      # Request usando httr2
      req <- request(url) %>%
        req_url_query(!!!query_params) %>%
        req_user_agent("Mozilla/5.0 (compatible; fiiscrapeR 2.0)") %>%
        req_timeout(60) %>%
        req_retry(max_tries = 3)

      # Executa request
      resp <- req_perform(req)

      if (!is_response_success(resp)) {
        status <- resp_status(resp)
        stop(glue("API returned status {status}"))
      }

      # Parse JSON
      data <- resp_body_json_parsed(resp)

      # Status Invest retorna duas listas: dateCom e datePayment
      # Vamos usar dateCom (data base) como principal
      if (is.null(data$dateCom) || length(data$dateCom) == 0) {
        logger$warn("API returned empty dateCom")
        return(create_result(
          success = TRUE,
          data = tibble(
            ticker = character(0),
            rendimento = numeric(0),
            data_base = as.Date(character(0)),
            data_pagamento = as.Date(character(0)),
            cota_base = numeric(0),
            dy = numeric(0)
          ),
          metadata = list(rows_collected = 0)
        ))
      }

      # Combina dateCom e datePayment
      income_raw <- bind_rows(data$dateCom, data$datePayment)

      logger$info(glue("Received {nrow(income_raw)} income records from API"))

      # Transforma para schema do income.rds
      # Status Invest schema:
      #   code, resultAbsoluteValue, dateCom, paymentDividend, earningType, dy
      # Target schema:
      #   ticker, rendimento, data_base, data_pagamento, cota_base, dy

      income_data <- income_raw %>%
        select(
          code,
          resultAbsoluteValue,
          dateCom,
          paymentDividend,
          earningType,
          dy
        ) %>%
        rename(
          ticker = code,
          earning_type = earningType
        ) %>%
        mutate(
          # Parse números brasileiros
          rendimento = parse_br_number(resultAbsoluteValue),
          dy = parse_br_number(dy),

          # Parse datas brasileiras
          data_base = parse_br_date(dateCom),
          data_pagamento = parse_br_date(paymentDividend),

          # Status Invest não fornece cota_base
          cota_base = NA_real_,

          # Normaliza earning_type para valores consistentes
          earning_type = case_when(
            is.na(earning_type) ~ "Rendimento",
            TRUE ~ earning_type
          )
        ) %>%
        select(ticker, rendimento, data_base, data_pagamento, cota_base, dy, earning_type) %>%
        # Remove registros inválidos
        filter(
          !is.na(ticker),
          !is.na(rendimento),
          !is.na(data_base)
        ) %>%
        # Normaliza ticker (uppercase)
        mutate(ticker = parse_br_ticker(ticker, strict = FALSE)) %>%
        # Remove duplicatas
        distinct()

      logger$info(glue("Transformed {nrow(income_data)} valid income records"))

      # Salva de forma incremental
      filepath <- config$data$income_file %||% "./data/income.rds"
      dedup_columns <- c("ticker", "data_base", "data_pagamento")

      logger$info(glue("Saving to {filepath}"))

      save_incremental(
        new_data = income_data,
        filepath = filepath,
        dedup_columns = dedup_columns,
        backup_dir = config$data$backup_dir %||% "data_backup",
        logger = logger
      )

      # Retorna resultado
      create_result(
        success = TRUE,
        data = income_data,
        metadata = list(
          rows_collected = nrow(income_data),
          date_range = list(
            start = start_date,
            end = end_date
          )
        )
      )

    }, error = function(e) {
      create_result(
        success = FALSE,
        error = e$message
      )
    })
  }

  # Cria collector usando base
  create_base_collector(
    name = "statusinvest_income",
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
