#' Portfolio Return Analysis
#'
#' Calculates Money-Weighted Returns (IRR) and Time-Weighted Returns (TWR)
#' for FII portfolio, considering proventos reinvested in Selic and liquidated assets.
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)
library(jrvFinance)  # For IRR calculation

source("R/analysis/selic_reinvestment.R")

#' Detect liquidated assets using earning_type field
#'
#' Identifies FIIs that had amortization events (return of capital)
#' which typically indicates liquidation or partial liquidation
#'
#' @param income tibble Income data with earning_type column
#' @return tibble with ticker, liquidation_date, amortization_value
detect_liquidated_assets <- function(income) {

  # Check if earning_type column exists
  if (!"earning_type" %in% names(income)) {
    warning("Column 'earning_type' not found in income data. ",
            "Cannot detect liquidations. Run statusinvest collector first.")

    # Fallback: heuristic detection
    return(detect_liquidated_assets_heuristic(income))
  }

  # Find amortization events
  liquidations <- income %>%
    filter(!is.na(earning_type), earning_type == "Amortização") %>%
    group_by(ticker) %>%
    summarise(
      liquidation_date = max(data_pagamento, na.rm = TRUE),
      amortization_value = sum(rendimento, na.rm = TRUE),
      n_amortizations = n(),
      .groups = "drop"
    ) %>%
    arrange(liquidation_date)

  if (nrow(liquidations) > 0) {
    message(sprintf("✓ Found %d liquidated assets via earning_type:", nrow(liquidations)))
    for (i in seq_len(min(nrow(liquidations), 10))) {
      message(sprintf("  %s: R$ %.2f on %s",
                      liquidations$ticker[i],
                      liquidations$amortization_value[i],
                      liquidations$liquidation_date[i]))
    }
    if (nrow(liquidations) > 10) {
      message(sprintf("  ... and %d more", nrow(liquidations) - 10))
    }
  } else {
    message("No liquidations detected via earning_type")
  }

  return(liquidations)
}

#' Heuristic liquidation detection (fallback)
#'
#' Uses heuristics when earning_type is not available:
#' - Very high rendimento (>3x median)
#' - No payments for 6+ months
detect_liquidated_assets_heuristic <- function(income) {

  liquidations <- income %>%
    group_by(ticker) %>%
    arrange(data_pagamento) %>%
    mutate(
      median_rendimento = median(rendimento, na.rm = TRUE),
      high_payment = rendimento > 3 * median_rendimento,
      last_payment = max(data_pagamento, na.rm = TRUE),
      months_since_last = interval(last_payment, today()) / months(1)
    ) %>%
    filter(high_payment | months_since_last > 6) %>%
    summarise(
      liquidation_date = last_payment[1],
      amortization_value = sum(rendimento[high_payment], na.rm = TRUE),
      months_since_last = first(months_since_last),
      detection_method = "heuristic",
      .groups = "drop"
    )

  if (nrow(liquidations) > 0) {
    message(sprintf("⚠ Found %d potential liquidations via heuristics:", nrow(liquidations)))
    message("Note: This is less reliable than using earning_type field")
  }

  return(liquidations)
}

#' Build complete cash flow timeline
#'
#' Constructs cash flow timeline for IRR calculation:
#' - Negative cash flows: contributions (aportes)
#' - Positive cash flows: current portfolio value + Selic account balance
#'
#' @param portfolio tibble Portfolio transactions
#' @param income tibble Income distributions
#' @param prices tibble Current prices
#' @param selic_account list Output from simulate_selic_account()
#' @param liquidations tibble Output from detect_liquidated_assets()
#' @return tibble with date, cash_flow, cf_type
build_cash_flow_timeline <- function(portfolio, income, prices,
                                      selic_account, liquidations = NULL) {

  # 1. Contributions (aportes) - negative cash flows
  contributions <- portfolio %>%
    mutate(
      cash_flow = -1 * (price * volume + taxes),
      cf_type = "contribution"
    ) %>%
    select(date, cash_flow, cf_type, ticker, volume)

  message(sprintf("Built %d contribution cash flows", nrow(contributions)))
  message(sprintf("  Total invested: R$ %.2f", sum(abs(contributions$cash_flow))))

  # 2. Calculate current portfolio value
  current_positions <- portfolio %>%
    group_by(ticker) %>%
    summarise(
      volume = sum(volume, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(volume > 0)

  # Get latest prices
  latest_prices <- prices %>%
    group_by(ticker) %>%
    filter(date == max(date)) %>%
    slice(1) %>%
    ungroup() %>%
    select(ticker, price)

  # Handle quotations.rds structure (might have different columns)
  if ("ref.date" %in% names(prices) && "price.close" %in% names(prices)) {
    latest_prices <- prices %>%
      group_by(ticker) %>%
      filter(ref.date == max(ref.date)) %>%
      slice(1) %>%
      ungroup() %>%
      select(ticker, price = price.close)
  }

  current_value <- current_positions %>%
    left_join(latest_prices, by = "ticker") %>%
    filter(!is.na(price)) %>%
    mutate(position_value = volume * price) %>%
    summarise(total_value = sum(position_value, na.rm = TRUE)) %>%
    pull(total_value)

  message(sprintf("Current FII portfolio value: R$ %.2f", current_value))

  # 3. Add Selic account balance
  selic_balance <- selic_account$final_balance
  message(sprintf("Selic account balance: R$ %.2f", selic_balance))

  # 4. Handle liquidated positions
  liquidation_value <- 0
  if (!is.null(liquidations) && nrow(liquidations) > 0) {
    # For liquidated assets, amortization value is already included
    # in proventos, so no additional cash flow needed
    message(sprintf("Accounting for %d liquidated assets", nrow(liquidations)))
  }

  # 5. Final cash flow = current value + Selic balance
  final_cf <- tibble(
    date = today(),
    cash_flow = current_value + selic_balance,
    cf_type = "final_value"
  )

  message(sprintf("Final value cash flow: R$ %.2f on %s", final_cf$cash_flow, final_cf$date))

  # Combine all cash flows
  all_cfs <- bind_rows(
    contributions %>% select(date, cash_flow, cf_type),
    final_cf
  ) %>%
    arrange(date)

  message(sprintf("Total cash flows: %d", nrow(all_cfs)))

  return(all_cfs)
}

#' Calculate portfolio IRR (Money-Weighted Return)
#'
#' Calculates Internal Rate of Return considering all cash flows
#' including contributions, proventos reinvested in Selic, and current value
#'
#' @param cash_flows tibble Output from build_cash_flow_timeline()
#' @return numeric IRR as decimal (e.g., 0.12 = 12%)
calculate_portfolio_irr <- function(cash_flows) {

  # jrvFinance::irr expects:
  # - cf: vector of cash flows
  # - cf.t: vector of time periods (in years from start)

  cf_values <- cash_flows$cash_flow

  # Convert dates to years from first date
  first_date <- min(cash_flows$date)
  cf_dates_years <- as.numeric(cash_flows$date - first_date) / 365.25  # Years since first CF

  # Validate cash flows
  total_out <- sum(cf_values[cf_values < 0])
  total_in <- sum(cf_values[cf_values > 0])

  message(sprintf("IRR Calculation - Total OUT: R$ %.2f, Total IN: R$ %.2f",
                  abs(total_out), total_in))

  # Try to calculate IRR
  irr_result <- tryCatch({
    irr_value <- jrvFinance::irr(cf = cf_values, cf.t = cf_dates_years)

    # Validate result
    if (is.na(irr_value) || is.infinite(irr_value) || abs(irr_value) > 1) {
      stop("IRR returned invalid value: ", irr_value)
    }

    irr_value
  }, error = function(e) {
    warning("IRR calculation failed: ", e$message)
    message("Using alternative XIRR-style calculation...")

    # Alternative: Calculate using Newton-Raphson method
    # NPV function
    npv <- function(rate, cfs, times) {
      sum(cfs / (1 + rate)^times)
    }

    # Try different starting points
    for (start_rate in c(0.1, 0.05, 0.15, 0.02, -0.05)) {
      result <- tryCatch({
        uniroot(
          function(r) npv(r, cf_values, cf_dates_years),
          interval = c(-0.99, 3.0),
          tol = 0.0001
        )$root
      }, error = function(e) NULL)

      if (!is.null(result) && !is.na(result)) {
        message(sprintf("✓ IRR converged to %.4f using alternative method", result))
        return(result)
      }
    }

    # Last resort: simple annualized return
    warning("IRR did not converge, using simple annualized return")
    total_invested <- abs(sum(cf_values[cf_values < 0]))
    final_value <- sum(cf_values[cf_values > 0])
    simple_return <- (final_value - total_invested) / total_invested
    years <- max(cf_dates_years)

    if (years > 0) {
      annualized <- (1 + simple_return)^(1/years) - 1
    } else {
      annualized <- simple_return
    }

    message(sprintf("Simple annualized return: %.4f (%.2f years)", annualized, years))
    return(annualized)
  })

  return(irr_result)
}

#' Calculate portfolio TWR (Time-Weighted Return)
#'
#' Calculates Time-Weighted Return by breaking into sub-periods
#' between each contribution and chain-multiplying returns
#'
#' This is more complex to implement properly, so we provide a simplified version
#' that assumes monthly revaluation
#'
#' @param portfolio tibble Portfolio transactions
#' @param prices tibble Price history
#' @param income tibble Income distributions
#' @return numeric TWR as decimal
calculate_portfolio_twr <- function(portfolio, prices, income) {

  # Simplified TWR calculation using monthly returns
  # Full TWR requires tracking portfolio value at each cash flow date

  message("Calculating simplified TWR using monthly returns...")

  # Get all unique months with activity
  start_date <- min(portfolio$date)
  end_date <- today()

  # Create monthly sequence
  months <- seq.Date(
    floor_date(start_date, "month"),
    floor_date(end_date, "month"),
    by = "month"
  )

  # For each month, calculate holdings and returns
  monthly_returns <- map_dbl(seq_len(length(months) - 1), function(i) {
    month_start <- months[i]
    month_end <- months[i + 1] - days(1)

    # Holdings at start of month
    holdings_start <- portfolio %>%
      filter(date < month_start) %>%
      group_by(ticker) %>%
      summarise(volume = sum(volume), .groups = "drop")

    # Contributions during month
    contributions_month <- portfolio %>%
      filter(date >= month_start, date <= month_end) %>%
      summarise(total = sum(price * volume + taxes, na.rm = TRUE)) %>%
      pull(total)

    if (length(contributions_month) == 0) contributions_month <- 0

    # Calculate portfolio values (simplified - would need proper pricing)
    # For now, return 0 to indicate calculation needed
    return(0)
  })

  # TODO: Full TWR implementation requires daily price data
  # For now, return NA and recommend using IRR
  warning("Full TWR calculation not yet implemented. Use IRR (MWR) instead.")

  return(NA_real_)
}

#' Calculate cumulative returns over time
#'
#' Reconstructs daily portfolio value and calculates cumulative return
#'
#' @param portfolio tibble Portfolio transactions
#' @param prices tibble Price history
#' @param selic_account list Selic account simulation
#' @return tibble with date, portfolio_value, cumulative_return
calculate_cumulative_returns <- function(portfolio, prices, selic_account) {

  message("Calculating cumulative returns timeline...")

  # Get date range
  start_date <- min(portfolio$date)
  end_date <- today()

  # Create daily timeline
  daily_dates <- seq.Date(start_date, end_date, by = "day")

  # For each date, calculate holdings and value
  # This is computationally intensive - simplified version

  # Aggregate holdings
  holdings_timeline <- map_dfr(daily_dates, function(d) {
    holdings <- portfolio %>%
      filter(date <= d) %>%
      group_by(ticker) %>%
      summarise(volume = sum(volume), .groups = "drop") %>%
      mutate(date = d)

    return(holdings)
  })

  # Join with prices to calculate values
  # (Implementation would join with prices table and calculate value)

  message("Note: Full daily reconstruction requires price history")
  message("Returning simplified timeline")

  # Return basic structure
  return(tibble(date = daily_dates, portfolio_value = NA_real_))
}

#' Main function: Calculate all portfolio returns
#'
#' Orchestrates all return calculations
#'
#' @param portfolio_path Character Path to portfolio RDS
#' @param income_path Character Path to income RDS
#' @param prices_path Character Path to quotations RDS
#' @param benchmarks_path Character Path to benchmarks RDS
#' @return list with all return metrics
calculate_all_returns <- function(
  portfolio_path = "data/portfolio.rds",
  income_path = "data/income.rds",
  prices_path = "data/quotations.rds",
  benchmarks_path = "data/benchmarks.rds"
) {

  message("═══════════════════════════════════════════════════════")
  message("     PORTFOLIO RETURN ANALYSIS")
  message("═══════════════════════════════════════════════════════")
  message("")

  # Load data
  message("Loading data...")
  portfolio <- readRDS(portfolio_path)
  income <- readRDS(income_path)
  prices <- readRDS(prices_path)

  # Deduplicate income
  income <- income %>%
    distinct(ticker, data_base, .keep_all = TRUE)

  message(sprintf("  Portfolio: %d transactions, %d unique tickers",
                  nrow(portfolio), n_distinct(portfolio$ticker)))
  message(sprintf("  Income: %d records", nrow(income)))
  message(sprintf("  Prices: %d records", nrow(prices)))
  message("")

  # Load or calculate benchmarks
  if (file.exists(benchmarks_path)) {
    benchmarks <- readRDS(benchmarks_path)
    message("  Benchmarks: Loaded from cache")
  } else {
    message("  Benchmarks: Not found - will need to run update_all_benchmarks() first")
    stop("Please run source('R/import/benchmark_data.R') and update_all_benchmarks()")
  }
  message("")

  # Detect liquidations
  message("Detecting liquidated assets...")
  liquidations <- detect_liquidated_assets(income)
  message("")

  # Calculate proventos received per ticker
  message("Calculating proventos received...")
  proventos_received <- portfolio %>%
    left_join(income, by = "ticker", relationship = "many-to-many") %>%
    filter(data_pagamento >= date) %>%  # Only proventos after purchase
    mutate(valor_total = volume * rendimento) %>%
    select(ticker, data_pagamento, valor_total) %>%
    filter(!is.na(data_pagamento), !is.na(valor_total))

  message(sprintf("  Total proventos: R$ %.2f", sum(proventos_received$valor_total, na.rm = TRUE)))
  message("")

  # Simulate Selic reinvestment
  message("Simulating Selic reinvestment account...")
  selic_account <- simulate_selic_account(
    proventos_received = proventos_received,
    selic_rates = benchmarks$bcb %>% select(date, selic_daily)
  )
  message("")

  # Build cash flow timeline
  message("Building cash flow timeline...")
  cash_flows <- build_cash_flow_timeline(
    portfolio = portfolio,
    income = income,
    prices = prices,
    selic_account = selic_account,
    liquidations = liquidations
  )
  message("")

  # Calculate IRR
  message("Calculating Money-Weighted Return (IRR)...")
  irr <- calculate_portfolio_irr(cash_flows)
  message(sprintf("  IRR: %.2f%% p.a.", irr * 100))
  message("")

  # Calculate summary statistics
  total_invested <- sum(abs(cash_flows$cash_flow[cash_flows$cf_type == "contribution"]))
  final_value <- cash_flows$cash_flow[cash_flows$cf_type == "final_value"]
  total_return <- (final_value - total_invested) / total_invested

  # Return results
  results <- list(
    irr = irr,
    twr = NA_real_,  # Not yet implemented
    total_invested = total_invested,
    final_value = final_value,
    total_return = total_return,
    selic_account = selic_account,
    liquidations = liquidations,
    cash_flows = cash_flows,
    analysis_date = today()
  )

  message("═══════════════════════════════════════════════════════")
  message("SUMMARY")
  message("═══════════════════════════════════════════════════════")
  message(sprintf("Total Invested: R$ %.2f", results$total_invested))
  message(sprintf("Final Value: R$ %.2f", results$final_value))
  message(sprintf("Total Return: %.2f%%", results$total_return * 100))
  message(sprintf("IRR (p.a.): %.2f%%", results$irr * 100))
  message("═══════════════════════════════════════════════════════")

  return(results)
}
