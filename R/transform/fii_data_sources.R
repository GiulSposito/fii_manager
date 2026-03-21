#' FII Data Sources - Consolidation Layer
#'
#' Functions to consolidate data from multiple sources:
#' - Local cache (data/*.rds)
#' - StatusInvest (indicators and proventos)
#' - CVM (future integration)
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(lubridate)

#' Load all cached data files
#'
#' @return List with portfolio, quotations, income, fiis datasets
#' @export
load_cached_data <- function() {
  list(
    portfolio = readRDS("./data/portfolio.rds"),
    quotations = readRDS("./data/quotations.rds"),
    income = readRDS("./data/income.rds"),
    fiis = readRDS("./data/fiis.rds")
  )
}

#' Get consolidated data for a single FII ticker
#'
#' @param ticker FII ticker code (e.g., "HGLG11")
#' @param cache List from load_cached_data() or NULL to load fresh
#' @return Tibble with consolidated data
#' @export
get_fii_data <- function(ticker, cache = NULL) {
  if (is.null(cache)) {
    cache <- load_cached_data()
  }

  # Latest price
  latest_price <- cache$quotations %>%
    filter(ticker == !!ticker) %>%
    filter(date == max(date)) %>%
    select(ticker, price, price_date = date)

  # 12-month income history
  income_12m <- cache$income %>%
    filter(ticker == !!ticker,
           data_pagamento >= today() - months(12)) %>%
    arrange(desc(data_pagamento))

  # Market data from fiis.com.br
  market_data <- cache$fiis %>%
    filter(ticker == !!ticker) %>%
    select(ticker, tipo_fii, patrimonio_cota, rendimento_12m,
           participacao_ifix, numero_cotista, patrimonio, administrador)

  # Portfolio position (if owned)
  portfolio_position <- cache$portfolio %>%
    filter(ticker == !!ticker) %>%
    summarise(
      shares_owned = sum(volume),
      invested = sum(value),
      avg_price = weighted.mean(price, volume)
    )

  # Combine all sources
  result <- latest_price %>%
    left_join(market_data, by = "ticker") %>%
    mutate(
      income_history = list(income_12m),
      portfolio_position = list(portfolio_position)
    )

  return(result)
}

#' Get StatusInvest indicators for a FII
#'
#' @param ticker FII ticker code
#' @return Tibble with indicators from StatusInvest
#' @export
get_statusinvest_indicators <- function(ticker) {
  source("./R/_draft/statusinvest_indicators.R")

  url <- glue::glue("https://statusinvest.com.br/fundos-imobiliarios/{ticker}")

  tryCatch({
    cards <- get_fii_cards(url)

    # Reshape to wide format for easier use
    cards_wide <- cards %>%
      select(area, name, value_num) %>%
      pivot_wider(
        names_from = c(area, name),
        values_from = value_num,
        names_sep = "_"
      ) %>%
      mutate(ticker = ticker, .before = 1)

    return(cards_wide)
  },
  error = function(e) {
    warning(glue::glue("Failed to fetch StatusInvest data for {ticker}: {e$message}"))
    return(tibble(ticker = ticker))
  })
}

#' Get StatusInvest proventos history
#'
#' @param ticker FII ticker code
#' @param start_date Start date (default: 2 years ago)
#' @param end_date End date (default: today)
#' @return Tibble with provento history
#' @export
get_statusinvest_proventos <- function(ticker,
                                        start_date = today() - years(2),
                                        end_date = today()) {
  source("./R/_draft/statusinvest_proventos.R")

  tryCatch({
    earnings <- get_fii_earnings(
      filter = ticker,
      start = format(start_date, "%Y-%m-%d"),
      end = format(end_date, "%Y-%m-%d")
    )

    return(earnings)
  },
  error = function(e) {
    warning(glue::glue("Failed to fetch StatusInvest proventos for {ticker}: {e$message}"))
    return(tibble(ticker = ticker))
  })
}

#' Get comprehensive data for a FII from all sources
#'
#' @param ticker FII ticker code
#' @param include_statusinvest Whether to fetch StatusInvest data (slower)
#' @param cache Cached data or NULL
#' @return List with all available data
#' @export
get_comprehensive_fii_data <- function(ticker,
                                        include_statusinvest = TRUE,
                                        cache = NULL) {
  message(glue::glue("Collecting data for {ticker}..."))

  # Base data from cache
  base_data <- get_fii_data(ticker, cache)

  result <- list(
    ticker = ticker,
    base = base_data
  )

  # Optional: StatusInvest data
  if (include_statusinvest) {
    result$indicators_si <- get_statusinvest_indicators(ticker)
    result$proventos_si <- get_statusinvest_proventos(ticker)
  }

  return(result)
}

#' Validate data completeness for scoring
#'
#' @param fii_data Result from get_comprehensive_fii_data()
#' @return Tibble with data quality flags
#' @export
validate_fii_data <- function(fii_data) {
  tibble(
    ticker = fii_data$ticker,
    has_price = nrow(fii_data$base) > 0 && !is.na(fii_data$base$price),
    has_tipo = !is.na(fii_data$base$tipo_fii),
    has_income_12m = length(fii_data$base$income_history[[1]]$rendimento) > 0,
    has_pvp = !is.null(fii_data$indicators_si) &&
              any(str_detect(names(fii_data$indicators_si), "P.VP")),
    data_completeness = mean(c(has_price, has_tipo, has_income_12m, has_pvp))
  )
}
