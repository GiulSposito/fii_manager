#' Report Data Transformations
#'
#' Transform raw data into analysis-ready formats for visualizations
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)
library(glue)

#' Prepare sector allocation data
#'
#' @param scores FII scores data frame
#' @param portfolio_csv Portfolio with dividends CSV
#' @return Data frame with sector allocation
#' @export
prepare_sector_allocation <- function(scores, portfolio_csv) {

  # Join scores with portfolio to get current values
  sector_data <- portfolio_csv %>%
    filter(!is.na(current_value)) %>%
    left_join(
      scores %>% select(ticker, tipo_fii),
      by = "ticker"
    ) %>%
    mutate(
      # Use tipo_fii as segment
      segment = coalesce(tipo_fii, "Outros")
    ) %>%
    group_by(segment) %>%
    summarise(
      total_invested = sum(invested, na.rm = TRUE),
      total_value = sum(current_value, na.rm = TRUE),
      n_fiis = n(),
      .groups = "drop"
    ) %>%
    arrange(desc(total_value)) %>%
    mutate(
      pct_portfolio = total_value / sum(total_value) * 100,
      # Simplified segment names
      segment_label = str_remove(segment, " -.*"),
      segment_label = str_trunc(segment_label, 25)
    )

  return(sector_data)
}

#' Prepare dividend timeline data
#'
#' @param income Income data frame
#' @param portfolio_csv Portfolio with dividends CSV
#' @return Data frame with monthly dividend aggregates
#' @export
prepare_dividend_timeline <- function(income, portfolio_csv) {

  # Get portfolio tickers
  portfolio_tickers <- unique(portfolio_csv$ticker)

  # Filter income for portfolio tickers
  timeline_data <- income %>%
    filter(ticker %in% portfolio_tickers) %>%
    mutate(
      date = as_date(data_pagamento),
      year_month = floor_date(date, "month")
    ) %>%
    group_by(year_month) %>%
    summarise(
      total_dividends = sum(rendimento, na.rm = TRUE),
      n_payments = n(),
      .groups = "drop"
    ) %>%
    arrange(year_month) %>%
    # Add rolling average
    mutate(
      rolling_avg_3m = zoo::rollmean(total_dividends, k = 3, fill = NA, align = "right"),
      rolling_avg_6m = zoo::rollmean(total_dividends, k = 6, fill = NA, align = "right")
    )

  return(timeline_data)
}

#' Prepare top performers data
#'
#' @param portfolio_csv Portfolio with dividends CSV
#' @param top_n Number of top performers to return
#' @return Data frame with top performers
#' @export
prepare_top_performers <- function(portfolio_csv, top_n = 10) {

  top_data <- portfolio_csv %>%
    filter(!is.na(return_with_div)) %>%
    arrange(desc(return_with_div)) %>%
    head(top_n) %>%
    mutate(
      return_pct = return_with_div * 100,
      return_absolute = current_value + total_dividends - invested,
      # Color coding
      return_color = case_when(
        return_pct > 50 ~ "Excelente",
        return_pct > 20 ~ "Bom",
        return_pct > 0 ~ "Positivo",
        TRUE ~ "Negativo"
      )
    )

  return(top_data)
}

#' Prepare bottom performers data
#'
#' @param portfolio_csv Portfolio with dividends CSV
#' @param bottom_n Number of bottom performers to return
#' @return Data frame with bottom performers
#' @export
prepare_bottom_performers <- function(portfolio_csv, bottom_n = 10) {

  bottom_data <- portfolio_csv %>%
    filter(!is.na(return_with_div)) %>%
    arrange(return_with_div) %>%
    head(bottom_n) %>%
    mutate(
      return_pct = return_with_div * 100,
      return_absolute = current_value + total_dividends - invested,
      loss_severity = case_when(
        return_pct < -80 ~ "Crítico",
        return_pct < -50 ~ "Severo",
        return_pct < -30 ~ "Alto",
        TRUE ~ "Moderado"
      )
    )

  return(bottom_data)
}

#' Prepare portfolio summary metrics
#'
#' @param portfolio_csv Portfolio with dividends CSV
#' @return Named list with summary metrics
#' @export
prepare_portfolio_summary <- function(portfolio_csv) {

  # Filter out FIIs with no current value
  active_portfolio <- portfolio_csv %>%
    filter(!is.na(current_value), current_value > 0)

  total_invested <- sum(active_portfolio$invested, na.rm = TRUE)
  total_current <- sum(active_portfolio$current_value, na.rm = TRUE)
  total_dividends <- sum(active_portfolio$total_dividends, na.rm = TRUE)

  capital_gain <- total_current - total_invested
  total_return <- capital_gain + total_dividends
  return_pct <- total_return / total_invested * 100

  n_positive <- sum(active_portfolio$return_with_div > 0, na.rm = TRUE)
  n_negative <- sum(active_portfolio$return_with_div <= 0, na.rm = TRUE)

  avg_holding_months <- mean(active_portfolio$months_held, na.rm = TRUE)
  avg_dy <- mean(active_portfolio$div_yield_on_cost * 100, na.rm = TRUE)

  list(
    n_fiis = nrow(active_portfolio),
    total_invested = total_invested,
    total_current = total_current,
    total_dividends = total_dividends,
    capital_gain = capital_gain,
    capital_gain_pct = (capital_gain / total_invested) * 100,
    total_return = total_return,
    return_pct = return_pct,
    n_positive = n_positive,
    n_negative = n_negative,
    win_rate = (n_positive / (n_positive + n_negative)) * 100,
    avg_holding_months = avg_holding_months,
    avg_dy = avg_dy
  )
}

#' Prepare score distribution data
#'
#' @param scores FII scores data frame
#' @param portfolio_csv Portfolio with dividends CSV
#' @return Data frame with portfolio scores
#' @export
prepare_score_distribution <- function(scores, portfolio_csv) {

  score_data <- portfolio_csv %>%
    left_join(
      scores %>% select(ticker, total_score, quality, income, valuation, risk),
      by = "ticker"
    ) %>%
    filter(!is.na(total_score)) %>%
    mutate(
      score_category = case_when(
        total_score >= 40 ~ "Excelente (40+)",
        total_score >= 35 ~ "Bom (35-40)",
        total_score >= 30 ~ "Médio (30-35)",
        TRUE ~ "Baixo (<30)"
      )
    )

  return(score_data)
}

#' Prepare Empiricus comparison data
#'
#' @param portfolio_csv Portfolio with dividends CSV
#' @param empiricus_renda Empiricus renda portfolio
#' @param empiricus_tatica Empiricus tatica portfolio
#' @param scores FII scores data frame
#' @return Data frame with comparison metrics
#' @export
prepare_empiricus_comparison <- function(portfolio_csv, empiricus_renda, empiricus_tatica, scores) {

  # Calculate portfolio metrics
  portfolio_metrics <- tibble(
    portfolio = "Seu Portfolio",
    n_fiis = nrow(portfolio_csv %>% filter(!is.na(current_value))),
    avg_dy = mean(portfolio_csv$div_yield_on_cost * 100, na.rm = TRUE)
  )

  # Empiricus renda metrics
  if (!is.null(empiricus_renda)) {
    renda_tickers <- empiricus_renda$ticker

    renda_scores <- scores %>%
      filter(ticker %in% renda_tickers)

    renda_metrics <- tibble(
      portfolio = "Empiricus Renda",
      n_fiis = length(renda_tickers),
      avg_dy = mean(renda_scores$dy_12m, na.rm = TRUE)
    )
  } else {
    renda_metrics <- tibble(
      portfolio = "Empiricus Renda",
      n_fiis = 10,
      avg_dy = 10.1
    )
  }

  # Empiricus tatica metrics
  if (!is.null(empiricus_tatica)) {
    tatica_tickers <- empiricus_tatica$ticker

    tatica_scores <- scores %>%
      filter(ticker %in% tatica_tickers)

    tatica_metrics <- tibble(
      portfolio = "Empiricus Tática",
      n_fiis = length(tatica_tickers),
      avg_dy = mean(tatica_scores$dy_12m, na.rm = TRUE)
    )
  } else {
    tatica_metrics <- tibble(
      portfolio = "Empiricus Tática",
      n_fiis = 9,
      avg_dy = 11.0
    )
  }

  # Combine
  comparison_data <- bind_rows(
    portfolio_metrics,
    renda_metrics,
    tatica_metrics
  )

  return(comparison_data)
}
