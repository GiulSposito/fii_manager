#' Portfolio Strategy Comparison
#'
#' Compares the FII + Selic reinvestment strategy against
#' pure benchmark investment strategies
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)

#' Compare strategy with "what if I invested everything in X"
#'
#' For each benchmark, calculates what the final value would be
#' if all contributions were invested in that benchmark instead
#'
#' @param portfolio_returns list Output from calculate_all_returns()
#' @param benchmarks list Benchmark data
#' @param start_date Date Portfolio start date
#' @return tibble with comparison
compare_strategy_vs_benchmarks <- function(portfolio_returns, benchmarks, start_date) {

  message("═══════════════════════════════════════════════════════")
  message("  STRATEGY COMPARISON: FII+Selic vs Pure Benchmarks")
  message("═══════════════════════════════════════════════════════")
  message("")

  # Get all contributions from cash flows
  contributions <- portfolio_returns$cash_flows %>%
    filter(cf_type == "contribution") %>%
    arrange(date)

  total_invested <- abs(sum(contributions$cash_flow))

  message(sprintf("Total contributions: %d", nrow(contributions)))
  message(sprintf("Total invested: R$ %.2f", total_invested))
  message(sprintf("Period: %s to %s", min(contributions$date), today()))
  message("")

  # Portfolio strategy result
  portfolio_final <- portfolio_returns$final_value
  portfolio_return <- (portfolio_final / total_invested - 1) * 100

  # Calculate what each benchmark would have returned
  results <- tibble(
    strategy = character(),
    final_value = numeric(),
    total_return_pct = numeric(),
    annualized_return_pct = numeric(),
    gain_loss = numeric()
  )

  # Portfolio strategy (actual)
  years <- as.numeric(difftime(today(), start_date, units = "days")) / 365.25
  portfolio_cagr <- (portfolio_final / total_invested)^(1/years) - 1

  results <- results %>%
    add_row(
      strategy = "Portfolio (FII + Selic)",
      final_value = portfolio_final,
      total_return_pct = portfolio_return,
      annualized_return_pct = portfolio_cagr * 100,
      gain_loss = portfolio_final - total_invested
    )

  # Selic strategy
  selic_final <- simulate_benchmark_investment(
    contributions,
    benchmarks$bcb %>% select(date, daily_return = selic_daily),
    "Selic"
  )

  selic_cagr <- (selic_final / total_invested)^(1/years) - 1

  results <- results %>%
    add_row(
      strategy = "100% Selic",
      final_value = selic_final,
      total_return_pct = (selic_final / total_invested - 1) * 100,
      annualized_return_pct = selic_cagr * 100,
      gain_loss = selic_final - total_invested
    )

  # CDI strategy
  cdi_final <- simulate_benchmark_investment(
    contributions,
    benchmarks$bcb %>% select(date, daily_return = cdi_daily),
    "CDI"
  )

  cdi_cagr <- (cdi_final / total_invested)^(1/years) - 1

  results <- results %>%
    add_row(
      strategy = "100% CDI",
      final_value = cdi_final,
      total_return_pct = (cdi_final / total_invested - 1) * 100,
      annualized_return_pct = cdi_cagr * 100,
      gain_loss = cdi_final - total_invested
    )

  # CDB strategy
  cdb_final <- simulate_benchmark_investment(
    contributions,
    benchmarks$bcb %>% select(date, daily_return = cdb_daily),
    "CDB"
  )

  cdb_cagr <- (cdb_final / total_invested)^(1/years) - 1

  results <- results %>%
    add_row(
      strategy = "100% CDB (95% CDI)",
      final_value = cdb_final,
      total_return_pct = (cdb_final / total_invested - 1) * 100,
      annualized_return_pct = cdb_cagr * 100,
      gain_loss = cdb_final - total_invested
    )

  # IFIX strategy
  ifix_returns <- benchmarks$equity %>%
    filter(ticker == "IFIX") %>%
    select(date, daily_return)

  ifix_final <- simulate_benchmark_investment(
    contributions,
    ifix_returns,
    "IFIX"
  )

  ifix_cagr <- (ifix_final / total_invested)^(1/years) - 1

  results <- results %>%
    add_row(
      strategy = "100% IFIX",
      final_value = ifix_final,
      total_return_pct = (ifix_final / total_invested - 1) * 100,
      annualized_return_pct = ifix_cagr * 100,
      gain_loss = ifix_final - total_invested
    )

  # Ibovespa strategy
  ibov_returns <- benchmarks$equity %>%
    filter(ticker == "IBOV") %>%
    select(date, daily_return)

  ibov_final <- simulate_benchmark_investment(
    contributions,
    ibov_returns,
    "Ibovespa"
  )

  ibov_cagr <- (ibov_final / total_invested)^(1/years) - 1

  results <- results %>%
    add_row(
      strategy = "100% Ibovespa",
      final_value = ibov_final,
      total_return_pct = (ibov_final / total_invested - 1) * 100,
      annualized_return_pct = ibov_cagr * 100,
      gain_loss = ibov_final - total_invested
    )

  # Sort by final value descending
  results <- results %>%
    arrange(desc(final_value)) %>%
    mutate(
      rank = row_number(),
      vs_portfolio = final_value - results$final_value[1]
    )

  message("")
  message("RESULTS SUMMARY:")
  message("─────────────────────────────────────────────────────────")

  for (i in seq_len(nrow(results))) {
    row <- results[i, ]
    message(sprintf("%d. %-25s R$ %s (%+.1f%% p.a.)",
                    row$rank,
                    row$strategy,
                    format(row$final_value, big.mark = ".", decimal.mark = ",", nsmall = 2),
                    row$annualized_return_pct))
  }

  message("─────────────────────────────────────────────────────────")
  message("")

  return(results)
}

#' Simulate investing all contributions in a benchmark
#'
#' @param contributions tibble Cash flows with date and cash_flow
#' @param benchmark_returns tibble Daily returns with date and daily_return
#' @param name character Benchmark name for logging
#' @return numeric Final value
simulate_benchmark_investment <- function(contributions, benchmark_returns, name) {

  # Create daily timeline
  start_date <- as.Date(min(contributions$date))  # Convert POSIXct to Date
  end_date <- today()

  timeline <- tibble(date = seq.Date(start_date, end_date, by = "day"))

  # Merge benchmark returns
  timeline <- timeline %>%
    left_join(benchmark_returns, by = "date") %>%
    fill(daily_return, .direction = "down") %>%
    mutate(daily_return = if_else(is.na(daily_return), 0, daily_return))

  # Aggregate contributions by date
  contribs_daily <- contributions %>%
    mutate(contribution = abs(cash_flow)) %>%
    group_by(date) %>%
    summarise(contribution = sum(contribution), .groups = "drop")

  timeline <- timeline %>%
    left_join(contribs_daily, by = "date") %>%
    mutate(contribution = if_else(is.na(contribution), 0, contribution))

  # Simulate day by day
  timeline$balance <- 0

  for (i in seq_len(nrow(timeline))) {
    if (i == 1) {
      timeline$balance[i] <- timeline$contribution[i]
    } else {
      prev_balance <- timeline$balance[i-1]
      growth <- prev_balance * timeline$daily_return[i]
      new_contrib <- timeline$contribution[i]
      timeline$balance[i] <- prev_balance + growth + new_contrib
    }
  }

  final_value <- last(timeline$balance)

  message(sprintf("  %s: R$ %.2f", name, final_value))

  return(final_value)
}

#' Generate strategy comparison report
#'
#' @param comparison tibble Output from compare_strategy_vs_benchmarks()
#' @param output_file character Output file path
generate_strategy_report <- function(comparison, output_file = "/tmp/strategy_comparison.txt") {

  report <- c(
    "═══════════════════════════════════════════════════════════════",
    "              INVESTMENT STRATEGY COMPARISON",
    "═══════════════════════════════════════════════════════════════",
    "",
    "Question: What if I had invested all my money in a single benchmark",
    "          instead of the FII + Selic reinvestment strategy?",
    "",
    "─────────────────────────────────────────────────────────────",
    "RANKING (by final value):",
    "─────────────────────────────────────────────────────────────",
    ""
  )

  for (i in seq_len(nrow(comparison))) {
    row <- comparison[i, ]

    report <- c(
      report,
      sprintf("Rank %d: %s", row$rank, row$strategy),
      sprintf("  Final Value:         R$ %s",
              format(row$final_value, big.mark = ".", decimal.mark = ",", nsmall = 2)),
      sprintf("  Total Return:        %+.2f%%", row$total_return_pct),
      sprintf("  Annualized Return:   %+.2f%% p.a.", row$annualized_return_pct),
      sprintf("  Gain/Loss:           R$ %s",
              format(row$gain_loss, big.mark = ".", decimal.mark = ",", nsmall = 2)),
      ""
    )

    if (i == 1) {
      report <- c(report, "")
    }
  }

  # Add comparison vs portfolio
  portfolio_value <- comparison$final_value[comparison$strategy == "Portfolio (FII + Selic)"]

  report <- c(
    report,
    "─────────────────────────────────────────────────────────────",
    "VS PORTFOLIO (FII + Selic):",
    "─────────────────────────────────────────────────────────────",
    ""
  )

  for (i in seq_len(nrow(comparison))) {
    row <- comparison[i, ]

    if (row$strategy != "Portfolio (FII + Selic)") {
      diff <- row$final_value - portfolio_value
      diff_pct <- (diff / portfolio_value) * 100

      symbol <- if_else(diff > 0, "✓", "✗")
      action <- if_else(diff > 0, "better", "worse")

      report <- c(
        report,
        sprintf("%s %-25s %s by R$ %s (%+.1f%%)",
                symbol,
                row$strategy,
                action,
                format(abs(diff), big.mark = ".", decimal.mark = ",", nsmall = 2),
                diff_pct)
      )
    }
  }

  report <- c(
    report,
    "",
    "─────────────────────────────────────────────────────────────",
    "",
    sprintf("Report saved to: %s", output_file),
    "═══════════════════════════════════════════════════════════════"
  )

  # Write to file
  writeLines(report, output_file)

  # Print to console
  cat(paste(report, collapse = "\n"), "\n")

  return(report)
}
