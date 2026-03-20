# consistency_validator.R
# Validação de consistência entre fontes de dados
# Verifica se dados de diferentes sources estão alinhados

library(dplyr)
library(glue)

#' Validate Cross-Source Consistency
#'
#' Checks consistency between different data sources.
#'
#' @param data_dir Directory with RDS files
#' @param logger Logger instance
#' @return Consistency validation result
#' @export
validate_consistency <- function(data_dir = "data", logger = NULL) {
  if (!is.null(logger)) {
    logger$info("Validating cross-source consistency...")
  }

  issues <- list()

  # Load data files
  income_path <- file.path(data_dir, "income.rds")
  portfolio_path <- file.path(data_dir, "portfolio.rds")
  quotations_path <- file.path(data_dir, "quotations.rds")
  fiis_path <- file.path(data_dir, "fiis.rds")

  # Check 1: Income tickers should be in portfolio
  if (file.exists(income_path) && file.exists(portfolio_path)) {
    income <- readRDS(income_path)
    portfolio <- readRDS(portfolio_path)

    income_tickers <- unique(income$ticker)
    portfolio_tickers <- unique(portfolio$ticker)

    missing_in_portfolio <- setdiff(income_tickers, portfolio_tickers)
    if (length(missing_in_portfolio) > 0) {
      issues$missing_in_portfolio <- missing_in_portfolio
      if (!is.null(logger)) {
        logger$warn(glue("{length(missing_in_portfolio)} tickers in income but not in portfolio"))
      }
    }
  }

  # Check 2: Portfolio tickers should have quotations
  if (file.exists(portfolio_path) && file.exists(quotations_path)) {
    if (!exists("portfolio")) portfolio <- readRDS(portfolio_path)
    quotations <- readRDS(quotations_path)

    portfolio_tickers <- unique(portfolio$ticker)
    quotations_tickers <- unique(quotations$ticker)

    missing_quotations <- setdiff(portfolio_tickers, quotations_tickers)
    if (length(missing_quotations) > 0) {
      issues$missing_quotations <- missing_quotations
      if (!is.null(logger)) {
        logger$warn(glue("{length(missing_quotations)} portfolio tickers without quotations"))
      }
    }
  }

  # Check 3: All tickers should be in FIIs metadata
  if (file.exists(fiis_path)) {
    fiis <- readRDS(fiis_path)
    fiis_tickers <- unique(fiis$ticker)

    all_tickers <- unique(c(
      if (exists("income")) income$ticker else character(0),
      if (exists("portfolio")) portfolio$ticker else character(0),
      if (exists("quotations")) quotations$ticker else character(0)
    ))

    missing_metadata <- setdiff(all_tickers, fiis_tickers)
    if (length(missing_metadata) > 0) {
      issues$missing_metadata <- missing_metadata
      if (!is.null(logger)) {
        logger$warn(glue("{length(missing_metadata)} tickers without FII metadata"))
      }
    }
  }

  # Check 4: Income dates should have corresponding quotations
  if (file.exists(income_path) && file.exists(quotations_path)) {
    if (!exists("income")) income <- readRDS(income_path)
    if (!exists("quotations")) quotations <- readRDS(quotations_path)

    # Check if income has cota_base or we can find it in quotations
    income_with_missing_cota <- income %>%
      filter(is.na(cota_base)) %>%
      select(ticker, data_base)

    if (nrow(income_with_missing_cota) > 0) {
      # Try to find in quotations
      quotations_dates <- quotations %>%
        mutate(date = as.Date(date)) %>%
        select(ticker, date, price)

      missing_count <- income_with_missing_cota %>%
        left_join(quotations_dates, by = c("ticker", "data_base" = "date")) %>%
        filter(is.na(price)) %>%
        nrow()

      if (missing_count > 0) {
        issues$missing_cota_base <- missing_count
        if (!is.null(logger)) {
          logger$warn(glue("{missing_count} income records missing cota_base and no quotation available"))
        }
      }
    }
  }

  # Check 5: Portfolio dates should be chronological per ticker
  if (file.exists(portfolio_path)) {
    if (!exists("portfolio")) portfolio <- readRDS(portfolio_path)

    chronological_issues <- portfolio %>%
      arrange(ticker, date) %>%
      group_by(ticker) %>%
      mutate(
        prev_date = lag(date),
        is_chronological = is.na(prev_date) | date >= prev_date
      ) %>%
      filter(!is_chronological) %>%
      nrow()

    if (chronological_issues > 0) {
      issues$chronological_issues <- chronological_issues
      if (!is.null(logger)) {
        logger$warn(glue("{chronological_issues} portfolio records out of chronological order"))
      }
    }
  }

  # Summary
  valid <- length(issues) == 0

  if (!is.null(logger)) {
    if (valid) {
      logger$info("✓ Cross-source consistency OK")
    } else {
      logger$warn(glue("✗ Found {length(issues)} consistency issues"))
    }
  }

  list(
    valid = valid,
    issues = issues
  )
}

#' Enrich Income with Quotations
#'
#' Fills missing cota_base in income using quotations.
#'
#' @param income_path Path to income.rds
#' @param quotations_path Path to quotations.rds
#' @param logger Logger instance
#' @return Enriched income data frame
#' @export
enrich_income_with_quotations <- function(income_path = "data/income.rds",
                                           quotations_path = "data/quotations.rds",
                                           logger = NULL) {
  if (!file.exists(income_path) || !file.exists(quotations_path)) {
    stop("Income or quotations file not found")
  }

  income <- readRDS(income_path)
  quotations <- readRDS(quotations_path)

  if (!is.null(logger)) {
    missing_before <- sum(is.na(income$cota_base))
    logger$info(glue("Enriching income: {missing_before} missing cota_base values"))
  }

  # Prepare quotations
  quotations_dates <- quotations %>%
    mutate(date = as.Date(date)) %>%
    select(ticker, date, price)

  # Fill missing cota_base
  income_enriched <- income %>%
    left_join(
      quotations_dates,
      by = c("ticker", "data_base" = "date"),
      suffix = c("", "_quotation")
    ) %>%
    mutate(
      cota_base = if_else(is.na(cota_base), price, cota_base)
    ) %>%
    select(-price)

  if (!is.null(logger)) {
    missing_after <- sum(is.na(income_enriched$cota_base))
    filled <- missing_before - missing_after
    logger$info(glue("Filled {filled} cota_base values from quotations"))
    if (missing_after > 0) {
      logger$warn(glue("Still {missing_after} missing cota_base values"))
    }
  }

  income_enriched
}

#' Check Ticker Universe Consistency
#'
#' Compares ticker universes across sources.
#'
#' @param data_dir Directory with RDS files
#' @param logger Logger instance
#' @return Ticker universe comparison
#' @export
check_ticker_universe <- function(data_dir = "data", logger = NULL) {
  if (!is.null(logger)) {
    logger$info("Checking ticker universe...")
  }

  universes <- list()

  # Load each source
  files <- c(
    income = "income.rds",
    portfolio = "portfolio.rds",
    quotations = "quotations.rds",
    fiis = "fiis.rds"
  )

  for (name in names(files)) {
    filepath <- file.path(data_dir, files[[name]])
    if (file.exists(filepath)) {
      data <- readRDS(filepath)
      universes[[name]] <- unique(data$ticker)
    }
  }

  # Compare universes
  all_tickers <- unique(unlist(universes))

  comparison <- data.frame(
    ticker = all_tickers,
    in_income = all_tickers %in% (universes$income %||% character(0)),
    in_portfolio = all_tickers %in% (universes$portfolio %||% character(0)),
    in_quotations = all_tickers %in% (universes$quotations %||% character(0)),
    in_fiis = all_tickers %in% (universes$fiis %||% character(0))
  )

  # Identify issues
  incomplete <- comparison %>%
    filter(!(in_income & in_portfolio & in_quotations & in_fiis))

  if (!is.null(logger)) {
    logger$info(glue("Total tickers: {nrow(comparison)}"))
    logger$info(glue("  In income: {sum(comparison$in_income)}"))
    logger$info(glue("  In portfolio: {sum(comparison$in_portfolio)}"))
    logger$info(glue("  In quotations: {sum(comparison$in_quotations)}"))
    logger$info(glue("  In fiis metadata: {sum(comparison$in_fiis)}"))

    if (nrow(incomplete) > 0) {
      logger$warn(glue("{nrow(incomplete)} tickers not in all sources"))
    }
  }

  list(
    comparison = comparison,
    incomplete = incomplete,
    universes = universes
  )
}

#' Coalesce NULL Helper
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
