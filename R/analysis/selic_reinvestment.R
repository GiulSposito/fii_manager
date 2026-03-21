#' Selic Reinvestment Account Simulator
#'
#' Simulates a virtual savings account where all proventos (income distributions)
#' are reinvested at Selic rate with daily compounding.
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)

#' Simulate Selic reinvestment account
#'
#' Models a virtual account where proventos are deposited and earn Selic rate
#' with daily compounding. This represents the alternative investment strategy
#' of taking income distributions as cash and investing in Selic-linked savings.
#'
#' @param proventos_received tibble with columns: date (or data_pagamento), value (or valor_total)
#' @param selic_rates tibble with columns: date, selic_daily (daily Selic rate as decimal)
#' @return list with timeline (daily balances) and final_balance
#'
#' @examples
#' # Example: R$ 100/month for 12 months at 10% Selic
#' proventos <- tibble(
#'   date = seq.Date(ymd("2020-01-01"), ymd("2020-12-01"), by="month"),
#'   value = 100
#' )
#' selic <- tibble(
#'   date = seq.Date(ymd("2020-01-01"), ymd("2020-12-31"), by="day"),
#'   selic_daily = ((1 + 0.10)^(1/252)) - 1  # 10% annual to daily
#' )
#' result <- simulate_selic_account(proventos, selic)
simulate_selic_account <- function(proventos_received, selic_rates) {

  # Standardize column names
  if ("data_pagamento" %in% names(proventos_received)) {
    proventos_received <- proventos_received %>%
      rename(date = data_pagamento)
  }

  if ("valor_total" %in% names(proventos_received)) {
    proventos_received <- proventos_received %>%
      rename(value = valor_total)
  }

  # Validate inputs
  if (!all(c("date", "value") %in% names(proventos_received))) {
    stop("proventos_received must have 'date' and 'value' columns")
  }

  if (!all(c("date", "selic_daily") %in% names(selic_rates))) {
    stop("selic_rates must have 'date' and 'selic_daily' columns")
  }

  # Get date range
  start_date <- min(c(min(proventos_received$date, na.rm = TRUE),
                      min(selic_rates$date, na.rm = TRUE)))
  end_date <- max(c(max(proventos_received$date, na.rm = TRUE),
                    max(selic_rates$date, na.rm = TRUE),
                    today()))

  # Create daily timeline
  account <- tibble(date = seq.Date(start_date, end_date, by = "day"))

  # Merge Selic rates
  account <- account %>%
    left_join(selic_rates %>% select(date, selic_daily), by = "date") %>%
    # Fill missing Selic rates forward (weekends, holidays)
    fill(selic_daily, .direction = "down") %>%
    # If still missing, use 0 (no interest)
    mutate(selic_daily = if_else(is.na(selic_daily), 0, selic_daily))

  # Aggregate proventos by date (in case multiple on same day)
  proventos_daily <- proventos_received %>%
    group_by(date) %>%
    summarise(provento_in = sum(value, na.rm = TRUE), .groups = "drop")

  # Merge proventos into timeline
  account <- account %>%
    left_join(proventos_daily, by = "date") %>%
    mutate(provento_in = if_else(is.na(provento_in), 0, provento_in))

  # Initialize balance
  account$balance <- 0
  account$interest_earned <- 0

  # Simulate day by day with daily compounding
  for (i in seq_len(nrow(account))) {

    if (i == 1) {
      # First day: just add any proventos
      account$balance[i] <- account$provento_in[i]
      account$interest_earned[i] <- 0

    } else {
      # Subsequent days:
      # 1. Start with previous balance
      # 2. Apply daily Selic interest
      # 3. Add any new proventos

      prev_balance <- account$balance[i-1]
      daily_rate <- account$selic_daily[i]
      interest <- prev_balance * daily_rate
      new_proventos <- account$provento_in[i]

      account$balance[i] <- prev_balance + interest + new_proventos
      account$interest_earned[i] <- interest
    }
  }

  # Calculate cumulative statistics
  account <- account %>%
    mutate(
      cumulative_proventos = cumsum(provento_in),
      cumulative_interest = cumsum(interest_earned),
      total_return_pct = if_else(
        cumulative_proventos > 0,
        (balance - cumulative_proventos) / cumulative_proventos * 100,
        0
      )
    )

  # Return results
  result <- list(
    timeline = account,
    final_balance = last(account$balance),
    total_proventos_invested = sum(account$provento_in),
    total_interest_earned = sum(account$interest_earned),
    final_return_pct = last(account$total_return_pct),
    start_date = start_date,
    end_date = end_date,
    days = nrow(account)
  )

  message(sprintf("Selic Account Summary:"))
  message(sprintf("  Period: %s to %s (%d days)", start_date, end_date, result$days))
  message(sprintf("  Total Proventos Invested: R$ %.2f", result$total_proventos_invested))
  message(sprintf("  Interest Earned: R$ %.2f", result$total_interest_earned))
  message(sprintf("  Final Balance: R$ %.2f", result$final_balance))
  message(sprintf("  Return on Proventos: %.2f%%", result$final_return_pct))

  return(result)
}

#' Calculate equivalent Selic return for a given amount
#'
#' Simpler function that calculates what an initial investment would be worth
#' if invested at Selic rate from start_date to end_date
#'
#' @param initial_amount numeric Initial investment amount
#' @param selic_rates tibble with date, selic_daily
#' @param start_date Date Investment start date
#' @param end_date Date Investment end date (default: today())
#' @return list with final_value and annualized_return
calculate_selic_return <- function(initial_amount, selic_rates,
                                    start_date, end_date = today()) {

  # Filter Selic rates for period
  period_rates <- selic_rates %>%
    filter(date >= start_date, date <= end_date) %>%
    arrange(date)

  if (nrow(period_rates) == 0) {
    warning("No Selic rates available for period")
    return(list(final_value = initial_amount, annualized_return = 0))
  }

  # Compound daily returns
  compound_factor <- prod(1 + period_rates$selic_daily, na.rm = TRUE)
  final_value <- initial_amount * compound_factor

  # Calculate annualized return
  days <- as.numeric(difftime(end_date, start_date, units = "days"))
  years <- days / 365
  annualized_return <- (final_value / initial_amount)^(1/years) - 1

  return(list(
    final_value = final_value,
    total_return = (final_value / initial_amount) - 1,
    annualized_return = annualized_return,
    days = days,
    years = years
  ))
}

#' Plot Selic account evolution
#'
#' Visualizes the growth of the Selic reinvestment account over time
#'
#' @param selic_account list Output from simulate_selic_account()
#' @return ggplot object
plot_selic_account <- function(selic_account) {

  require(ggplot2)

  timeline <- selic_account$timeline

  p <- timeline %>%
    select(date, balance, cumulative_proventos, cumulative_interest) %>%
    pivot_longer(
      cols = c(balance, cumulative_proventos, cumulative_interest),
      names_to = "metric",
      values_to = "value"
    ) %>%
    mutate(
      metric = case_when(
        metric == "balance" ~ "Saldo Total",
        metric == "cumulative_proventos" ~ "Proventos Acumulados",
        metric == "cumulative_interest" ~ "Juros Acumulados"
      )
    ) %>%
    ggplot(aes(x = date, y = value, color = metric)) +
    geom_line(size = 1) +
    scale_y_continuous(labels = scales::dollar_format(prefix = "R$ ", big.mark = ".")) +
    labs(
      title = "Evolução da Conta Selic com Reinvestimento de Proventos",
      subtitle = sprintf("Período: %s a %s", selic_account$start_date, selic_account$end_date),
      x = "Data",
      y = "Valor (R$)",
      color = "Métrica"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      legend.position = "bottom"
    )

  return(p)
}
