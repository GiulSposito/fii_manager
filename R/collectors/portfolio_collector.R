# portfolio_collector.R
# Portfolio collector - wraps existing Google Sheets import
# Provides standard collector interface for portfolio data

library(googlesheets4)
library(dplyr)
library(glue)

# Importa dependências
source("R/utils/persistence.R")
source("R/collectors/collector_base.R")

#' Create Portfolio Google Sheets Collector
#'
#' Creates a collector for portfolio positions from Google Sheets.
#' Wraps the existing portfolioGoogleSheets.R import logic with
#' the standard collector pattern.
#'
#' @param config List with configuration (must contain data.portfolio)
#' @param logger Logger instance
#' @return Collector instance
#' @export
create_portfolio_googlesheets_collector <- function(config, logger) {

  # Função interna de coleta
  collect_fn <- function(config, logger) {
    tryCatch({
      # Get sheet_key from config
      # Config can come from data_sources.portfolio_googlesheets
      sheet_key <- config$sheet_key
      if (is.null(sheet_key)) {
        stop("Missing sheet_key in config")
      }

      # Output filepath
      filepath <- config$output %||% "portfolio.rds"
      if (!startsWith(filepath, "/") && !startsWith(filepath, ".")) {
        filepath <- file.path("data", filepath)
      }

      logger$info(glue("Reading portfolio from Google Sheets (key: {sheet_key})"))

      # Autentica Google Sheets se necessário
      # A autenticação deve estar configurada previamente ou será interativa
      # gs4_auth() é chamado automaticamente pelo googlesheets4 se necessário

      # Importa dados do Google Sheets
      spreadsheet <- read_sheet(sheet_key)

      logger$info(glue("Received {nrow(spreadsheet)} rows from Google Sheets"))

      # Formata dados - seguindo lógica de portfolioGoogleSheets.R
      portfolio <- spreadsheet %>%
        select(Data, Ativo, Qtd, Valor, Taxas, Total, Carteira) %>%
        setNames(c("date", "ticker", "volume", "price", "taxes", "value", "portfolio")) %>%
        filter(complete.cases(.))

      # Nota: O googlesheets4 já retorna os campos com tipos corretos
      # (numéricos como numeric, datas como Date), então não precisa parse manual

      logger$info(glue("Processed {nrow(portfolio)} valid portfolio records"))

      # Valida schema básico
      expected_cols <- c("date", "ticker", "volume", "price", "taxes", "value", "portfolio")
      missing_cols <- setdiff(expected_cols, names(portfolio))
      if (length(missing_cols) > 0) {
        stop(glue("Portfolio missing required columns: {paste(missing_cols, collapse=', ')}"))
      }

      # Salva localmente com backup
      logger$info(glue("Saving to {filepath}"))

      save_rds_with_backup(
        data = portfolio,
        filepath = filepath,
        backup_dir = "data_backup",
        logger = logger
      )

      # Retorna resultado
      create_result(
        success = TRUE,
        data = portfolio,
        metadata = list(
          rows_collected = nrow(portfolio),
          tickers = length(unique(portfolio$ticker)),
          portfolios = length(unique(portfolio$portfolio))
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
    name = "portfolio",
    config = config,
    logger = logger,
    collect_fn = collect_fn
  )
}

#' Get Portfolio
#'
#' Reads portfolio from local RDS file.
#'
#' @param filepath Character, path to portfolio.rds
#' @param logger Logger instance (optional)
#' @return Portfolio data frame or NULL on error
#' @export
get_portfolio <- function(filepath = "./data/portfolio.rds", logger = NULL) {
  load_rds_safe(filepath, default = NULL, logger = logger)
}

#' Coalesce NULL Helper
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
