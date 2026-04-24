# yahoo_prices_collector.R
# Coletor para Yahoo Finance prices (cotações históricas)
# Wrapper do código existente em R/import/pricesYahoo.R com padrão de collector

library(BatchGetSymbols)
library(dplyr)
library(lubridate)
library(glue)

source("R/utils/logging.R")
source("R/utils/persistence.R")
source("R/collectors/collector_base.R")

#' Create Yahoo Prices Collector
#'
#' @param config List with configuration
#' @param logger Logger instance
#' @return Collector instance
#' @export
create_yahoo_prices_collector <- function(config, logger) {
  collect_fn <- function(config, logger) {
    # Get portfolio tickers
    portfolio_file <- config$data$portfolio_file %||% "./data/portfolio.rds"
    if (!file.exists(portfolio_file)) {
      return(list(success = FALSE, error = "Portfolio file not found"))
    }
    portfolio <- readRDS(portfolio_file)
    tickers <- unique(portfolio$ticker)

    collect_yahoo_prices(tickers = tickers, config = config, logger = logger)
  }

  create_base_collector(
    name = "yahoo_prices",
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

#' Collect Yahoo Finance Prices for FII Portfolio
#'
#' Fetches historical price quotes from Yahoo Finance using BatchGetSymbols.
#' Returns quotations.rds schema compatible with existing pipeline.
#'
#' @param tickers Character vector of FII tickers (without .SA suffix)
#' @param first_date Date, start date for historical quotes (default: 2 years ago)
#' @param config List with collector configuration
#' @param logger Logger instance (optional)
#' @return List with success, data, metadata, and error (if any)
#' @export
collect_yahoo_prices <- function(tickers, first_date = NULL, config, logger = NULL) {
  start_time <- Sys.time()

  if (!is.null(logger)) {
    logger$info(glue("Starting Yahoo Finance collection for {length(tickers)} tickers"))
  }

  result <- list(
    success = FALSE,
    data = NULL,
    metadata = list(
      source = "yahoo_prices",
      collected_at = Sys.time(),
      tickers_total = length(tickers),
      tickers_success = 0,
      rows = 0
    ),
    error = NULL
  )

  tryCatch({
    # Default first_date: 2 anos atrás
    if (is.null(first_date)) {
      first_date <- now() - years(2)
    }

    if (!is.null(logger)) {
      logger$info(glue("Fetching quotes from {as.Date(first_date)} to {Sys.Date()}"))
    }

    # Adiciona sufixo .SA para Yahoo Finance (Brasil)
    yahoo_tickers <- paste0(unique(tickers), ".SA")

    # Adiciona IFIX (índice de referência)
    yahoo_tickers <- c(yahoo_tickers, "IFIX")

    if (!is.null(logger)) {
      logger$debug(glue("Yahoo tickers: {paste(head(yahoo_tickers, 5), collapse=', ')}... ({length(yahoo_tickers)} total)"))
    }

    # Fetch com BatchGetSymbols
    batch_result <- BatchGetSymbols(
      tickers = yahoo_tickers,
      first.date = first_date,
      thresh.bad.data = 0.001
    )

    # Verifica resultado
    if (is.null(batch_result$df.tickers)) {
      stop("BatchGetSymbols returned NULL data")
    }

    if (!is.null(logger)) {
      logger$info(glue("BatchGetSymbols returned {nrow(batch_result$df.tickers)} rows"))
      logger$debug(glue("Download summary: {batch_result$df.control$total.success} success, {batch_result$df.control$total.not.found} not found"))
    }

    # Normaliza para o schema canônico de quotations.rds: {ticker, price, date}
    quotations <- batch_result$df.tickers %>%
      as_tibble() %>%
      mutate(ticker = gsub("\\.SA$", "", ticker)) %>%
      select(ticker, price = price.close, date = ref.date) %>%
      mutate(date = as.POSIXct(date)) %>%
      filter(!is.na(price)) %>%
      distinct()

    if (nrow(quotations) == 0) {
      stop("No quotes retrieved from Yahoo Finance")
    }

    # Conta tickers com sucesso
    tickers_success <- quotations %>%
      distinct(ticker) %>%
      nrow()

    if (!is.null(logger)) {
      logger$info(glue("Processed {nrow(quotations)} quotes for {tickers_success} tickers"))
    }

    # Merge com dados existentes (incremental)
    output_path <- file.path("data", config$output)
    existing <- load_rds_safe(output_path, default = NULL, logger = logger)

    if (!is.null(existing)) {
      # Merge incremental: bind + distinct
      quotations_final <- bind_rows(existing, quotations) %>%
        distinct()

      new_rows <- nrow(quotations_final) - nrow(existing)

      if (!is.null(logger)) {
        logger$info(glue("Merged: {nrow(existing)} existing + {nrow(quotations)} new = {nrow(quotations_final)} total ({new_rows} net new)"))
      }
    } else {
      quotations_final <- quotations

      if (!is.null(logger)) {
        logger$info("No existing data - saving fresh dataset")
      }
    }

    # Salvar com backup
    save_rds_with_backup(
      quotations_final,
      output_path,
      backup_dir = "data_backup",
      logger = logger
    )

    # Resultado final
    result$success <- TRUE
    result$data <- quotations_final
    result$metadata$tickers_success <- tickers_success
    result$metadata$rows <- nrow(quotations_final)
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

#' Fetch Ticker Prices (Low-level function)
#'
#' Direct wrapper for BatchGetSymbols. Used by collect_yahoo_prices.
#'
#' @param tickers Character vector of tickers (without .SA)
#' @param first_date Date, start date
#' @param logger Logger instance (optional)
#' @return Tibble with price data
#' @keywords internal
fetch_tickers_prices <- function(tickers, first_date = NULL, logger = NULL) {
  if (is.null(first_date)) {
    first_date <- now() - years(1)
  }

  yahoo_tickers <- c(paste0(tickers, ".SA"), "IFIX")

  cotacoes <- BatchGetSymbols(
    tickers = yahoo_tickers,
    first.date = first_date,
    thresh.bad.data = 0.001
  )

  cotacoes$df.tickers %>%
    as_tibble() %>%
    mutate(ticker = gsub("\\.SA$", "", ticker)) %>%
    select(ticker, price = price.close, date = ref.date) %>%
    mutate(date = as.POSIXct(date)) %>%
    filter(!is.na(price)) %>%
    distinct()
}

#' Update Portfolio Prices
#'
#' Convenience function to update prices for an entire portfolio.
#' Extracts tickers and first date from portfolio data.
#'
#' @param portfolio Tibble with portfolio data (must have 'ticker' and 'date' columns)
#' @param config List with collector configuration
#' @param logger Logger instance (optional)
#' @return List with success, data, metadata, and error
#' @export
update_portfolio_prices <- function(portfolio, config, logger = NULL) {
  if (!is.null(logger)) {
    logger$info("Updating prices for portfolio tickers")
  }

  # Valida portfolio
  if (!all(c("ticker", "date") %in% names(portfolio))) {
    stop("Portfolio must have 'ticker' and 'date' columns")
  }

  # Extrai tickers e data mínima
  tickers <- portfolio %>%
    pull(ticker) %>%
    unique()

  first_date <- portfolio %>%
    pull(date) %>%
    min(na.rm = TRUE)

  if (!is.null(logger)) {
    logger$info(glue("Portfolio has {length(tickers)} tickers, earliest date: {as.Date(first_date)}"))
  }

  # Coleta preços
  collect_yahoo_prices(
    tickers = tickers,
    first_date = first_date,
    config = config,
    logger = logger
  )
}

#' Get Specific Ticker Prices (Utility function)
#'
#' Fetches prices for specific tickers without saving.
#' Useful for ad-hoc queries.
#'
#' @param tickers Character vector of tickers
#' @param first_date Date, start date (default: 2 years ago)
#' @param logger Logger instance (optional)
#' @return Tibble with price data
#' @export
get_tickers_price <- function(tickers, first_date = NULL, logger = NULL) {
  if (is.null(first_date)) {
    first_date <- now() - years(2)
  }

  if (!is.null(logger)) {
    logger$debug(glue("Fetching prices for {length(tickers)} tickers"))
  }

  fetch_tickers_prices(tickers, first_date, logger)
}

#' Validate Quotations Schema
#'
#' @param data Tibble with quotations data
#' @param logger Logger instance (optional)
#' @return Logical, TRUE if valid
#' @keywords internal
validate_quotations_schema <- function(data, logger = NULL) {
  # Schema canônico: {ticker, price, date}
  required_cols <- c("ticker", "price", "date")

  missing <- setdiff(required_cols, names(data))

  if (length(missing) > 0) {
    if (!is.null(logger)) {
      logger$error(glue("Missing required columns: {paste(missing, collapse=', ')}"))
    }
    return(FALSE)
  }

  TRUE
}
