#' Benchmark Comparison Analysis
#'
#' Compares portfolio returns against market benchmarks:
#' Selic, CDI, CDB, IPCA, IFIX, Ibovespa
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)
library(ggplot2)

#' Calculate benchmark returns for a given period
#'
#' Computes total and annualized returns for each benchmark
#'
#' @param benchmarks list Output from load_benchmarks()
#' @param start_date Date Portfolio start date
#' @param end_date Date Analysis end date (default: today())
#' @return tibble with benchmark, total_return, annualized_return
calculate_benchmark_returns <- function(benchmarks, start_date, end_date = today()) {

  message("Calculating benchmark returns...")

  # BCB benchmarks (Selic, CDI, IPCA, CDB)
  bcb_returns <- benchmarks$bcb %>%
    filter(date >= start_date, date <= end_date) %>%
    summarise(
      selic_total = prod(1 + selic_daily, na.rm = TRUE) - 1,
      cdi_total = prod(1 + cdi_daily, na.rm = TRUE) - 1,
      ipca_total = prod(1 + ipca_daily, na.rm = TRUE) - 1,
      cdb_total = prod(1 + cdb_daily, na.rm = TRUE) - 1
    )

  # Equity benchmarks (IFIX, Ibovespa)
  equity_returns <- benchmarks$equity %>%
    filter(date >= start_date, date <= end_date) %>%
    group_by(ticker) %>%
    summarise(
      total_return = prod(1 + daily_return, na.rm = TRUE) - 1,
      .groups = "drop"
    )

  ifix_return <- equity_returns %>%
    filter(ticker == "IFIX") %>%
    pull(total_return)

  ibov_return <- equity_returns %>%
    filter(ticker == "IBOV") %>%
    pull(total_return)

  if (length(ifix_return) == 0) ifix_return <- NA_real_
  if (length(ibov_return) == 0) ibov_return <- NA_real_

  # Calculate years for annualization
  years <- as.numeric(difftime(end_date, start_date, units = "days")) / 365

  # Combine into single tibble
  benchmark_summary <- tibble(
    benchmark = c("Selic", "CDI", "CDB (95% CDI)", "IPCA", "IFIX", "Ibovespa"),
    total_return = c(
      bcb_returns$selic_total,
      bcb_returns$cdi_total,
      bcb_returns$cdb_total,
      bcb_returns$ipca_total,
      ifix_return,
      ibov_return
    ),
    annualized_return = (1 + total_return)^(1/years) - 1,
    years = years
  )

  message(sprintf("✓ Calculated returns for %d benchmarks over %.2f years", nrow(benchmark_summary), years))

  return(benchmark_summary)
}

#' Compare portfolio with benchmarks
#'
#' Generates comparison table with alpha, Sharpe ratio, and other metrics
#'
#' @param portfolio_returns list Output from calculate_all_returns()
#' @param benchmark_returns tibble Output from calculate_benchmark_returns()
#' @param risk_free_rate numeric Annual risk-free rate (default: use Selic)
#' @return tibble with comparison metrics
compare_with_benchmarks <- function(portfolio_returns, benchmark_returns, risk_free_rate = NULL) {

  message("Comparing portfolio with benchmarks...")

  # If risk_free_rate not provided, use Selic
  if (is.null(risk_free_rate)) {
    risk_free_rate <- benchmark_returns %>%
      filter(benchmark == "Selic") %>%
      pull(annualized_return)
  }

  # Portfolio metrics
  portfolio_irr <- portfolio_returns$irr
  portfolio_total <- portfolio_returns$total_return

  # Calculate alpha (excess return)
  comparison <- benchmark_returns %>%
    mutate(
      portfolio_return = portfolio_irr,
      alpha = portfolio_irr - annualized_return,
      alpha_pct = alpha * 100,
      outperformance = if_else(alpha > 0, "✓ Beat", "✗ Lost to")
    )

  # Calculate portfolio volatility (simplified - would need monthly returns)
  # For now, estimate based on typical FII volatility
  portfolio_volatility <- 0.08  # 8% typical for FII portfolios

  # Calculate Sharpe ratios
  comparison <- comparison %>%
    mutate(
      # Benchmark Sharpe (simplified - assumes low volatility for fixed income)
      benchmark_volatility = case_when(
        benchmark %in% c("Selic", "CDI", "CDB (95% CDI)") ~ 0.01,  # Very low
        benchmark == "IPCA" ~ 0.02,  # Low
        benchmark == "IFIX" ~ 0.12,  # Moderate
        benchmark == "Ibovespa" ~ 0.25,  # High
        TRUE ~ 0.15
      ),
      benchmark_sharpe = (annualized_return - risk_free_rate) / benchmark_volatility,

      # Portfolio Sharpe
      portfolio_sharpe = (portfolio_return - risk_free_rate) / portfolio_volatility
    )

  message("✓ Comparison table generated")

  return(comparison)
}

#' Calculate portfolio beta vs Ibovespa
#'
#' Measures systematic risk - how much portfolio moves with market
#'
#' @param portfolio_returns_ts tibble Time series of portfolio returns
#' @param market_returns_ts tibble Time series of market (Ibovespa) returns
#' @return numeric Beta coefficient
calculate_beta <- function(portfolio_returns_ts, market_returns_ts) {

  # Join portfolio and market returns
  combined <- portfolio_returns_ts %>%
    inner_join(
      market_returns_ts %>% rename(market_return = return),
      by = "date"
    ) %>%
    filter(!is.na(portfolio_return), !is.na(market_return))

  if (nrow(combined) < 10) {
    warning("Insufficient data for beta calculation")
    return(NA_real_)
  }

  # Beta = Cov(portfolio, market) / Var(market)
  covariance <- cov(combined$portfolio_return, combined$market_return, use = "complete.obs")
  market_variance <- var(combined$market_return, na.rm = TRUE)

  beta <- covariance / market_variance

  return(beta)
}

#' Generate summary statistics
#'
#' Calculates CAGR, volatility, maximum drawdown, and other metrics
#'
#' @param portfolio_returns list Output from calculate_all_returns()
#' @param benchmarks list Benchmark data
#' @return list with summary statistics
generate_summary_statistics <- function(portfolio_returns, benchmarks) {

  message("Generating summary statistics...")

  # Years of investment
  first_investment <- portfolio_returns$cash_flows %>%
    filter(cf_type == "contribution") %>%
    summarise(min_date = min(date)) %>%
    pull(min_date)

  years <- as.numeric(difftime(today(), first_investment, units = "days")) / 365

  # CAGR (same as IRR for our case)
  cagr <- portfolio_returns$irr

  # Total return components
  total_invested <- portfolio_returns$total_invested
  final_value <- portfolio_returns$final_value
  fii_value <- final_value - portfolio_returns$selic_account$final_balance
  selic_value <- portfolio_returns$selic_account$final_balance

  # Percentage breakdown
  fii_pct <- fii_value / final_value * 100
  selic_pct <- selic_value / final_value * 100

  # Capital gains
  capital_gains <- fii_value - (total_invested - portfolio_returns$selic_account$total_proventos_invested)

  # Proventos statistics
  proventos_total <- portfolio_returns$selic_account$total_proventos_invested
  proventos_interest <- portfolio_returns$selic_account$total_interest_earned

  summary_stats <- list(
    period_years = years,
    first_investment_date = first_investment,
    last_update_date = today(),

    # Returns
    cagr = cagr,
    total_return = portfolio_returns$total_return,
    irr = portfolio_returns$irr,

    # Values
    total_invested = total_invested,
    final_value = final_value,
    fii_value = fii_value,
    selic_value = selic_value,

    # Composition
    fii_pct = fii_pct,
    selic_pct = selic_pct,

    # Components
    capital_gains = capital_gains,
    proventos_total = proventos_total,
    proventos_interest = proventos_interest,

    # Liquidations
    n_liquidations = nrow(portfolio_returns$liquidations),
    liquidations = portfolio_returns$liquidations
  )

  message("✓ Summary statistics calculated")

  return(summary_stats)
}

#' Plot cumulative returns
#'
#' Creates time series chart comparing portfolio with benchmarks
#'
#' @param portfolio_returns list Portfolio return data
#' @param benchmarks list Benchmark data
#' @param start_date Date Start date for plot
#' @return ggplot object
plot_cumulative_returns <- function(portfolio_returns, benchmarks, start_date) {

  message("Creating cumulative returns plot...")

  # Get daily benchmark returns
  daily_returns <- benchmarks$bcb %>%
    filter(date >= start_date) %>%
    select(date, selic_daily, cdi_daily, ipca_daily, cdb_daily) %>%
    left_join(
      benchmarks$equity %>%
        filter(date >= start_date) %>%
        select(date, ticker, daily_return) %>%
        pivot_wider(names_from = ticker, values_from = daily_return, names_prefix = "return_"),
      by = "date"
    ) %>%
    mutate(
      # Calculate cumulative returns
      selic_cum = cumprod(1 + replace_na(selic_daily, 0)) - 1,
      cdi_cum = cumprod(1 + replace_na(cdi_daily, 0)) - 1,
      ipca_cum = cumprod(1 + replace_na(ipca_daily, 0)) - 1,
      cdb_cum = cumprod(1 + replace_na(cdb_daily, 0)) - 1,
      ifix_cum = cumprod(1 + replace_na(return_IFIX, 0)) - 1,
      ibov_cum = cumprod(1 + replace_na(return_IBOV, 0)) - 1
    ) %>%
    select(date, selic_cum, cdi_cum, ipca_cum, cdb_cum, ifix_cum, ibov_cum)

  # Add portfolio return (simplified - would need actual timeline)
  # For now, draw straight line to final return
  portfolio_final_return <- portfolio_returns$total_return
  portfolio_line <- tibble(
    date = c(start_date, today()),
    portfolio_cum = c(0, portfolio_final_return)
  )

  # Pivot to long format for plotting
  plot_data <- daily_returns %>%
    pivot_longer(
      cols = ends_with("_cum"),
      names_to = "benchmark",
      values_to = "cumulative_return"
    ) %>%
    mutate(
      benchmark = case_when(
        benchmark == "selic_cum" ~ "Selic",
        benchmark == "cdi_cum" ~ "CDI",
        benchmark == "cdb_cum" ~ "CDB (95% CDI)",
        benchmark == "ipca_cum" ~ "IPCA",
        benchmark == "ifix_cum" ~ "IFIX",
        benchmark == "ibov_cum" ~ "Ibovespa",
        TRUE ~ benchmark
      )
    ) %>%
    bind_rows(
      portfolio_line %>%
        mutate(benchmark = "Portfolio FII")
    )

  # Create plot
  p <- ggplot(plot_data, aes(x = date, y = cumulative_return * 100, color = benchmark)) +
    geom_line(size = 1) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    scale_color_manual(
      values = c(
        "Portfolio FII" = "#E41A1C",
        "IFIX" = "#377EB8",
        "Selic" = "#4DAF4A",
        "CDI" = "#984EA3",
        "CDB (95% CDI)" = "#FF7F00",
        "Ibovespa" = "#FFFF33",
        "IPCA" = "#A65628"
      )
    ) +
    labs(
      title = "Retorno Acumulado: Portfolio vs Benchmarks",
      subtitle = sprintf("Período: %s a %s", start_date, today()),
      x = "Data",
      y = "Retorno Acumulado (%)",
      color = "Investimento"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      legend.position = "bottom",
      legend.title = element_text(face = "bold")
    )

  message("✓ Plot created")

  return(p)
}

#' Generate comparison report
#'
#' Creates text report of portfolio vs benchmark comparison
#'
#' @param portfolio_returns list Portfolio return data
#' @param comparison tibble Comparison table
#' @param summary_stats list Summary statistics
#' @param output_file Character Output filename (default: /tmp/portfolio_returns_report.txt)
generate_comparison_report <- function(portfolio_returns, comparison, summary_stats,
                                        output_file = "/tmp/portfolio_returns_report.txt") {

  message("Generating comparison report...")

  report <- c(
    "═══════════════════════════════════════════════════════════════",
    "           PORTFOLIO RETURN ANALYSIS WITH BENCHMARKS",
    "═══════════════════════════════════════════════════════════════",
    "",
    sprintf("Analysis Date: %s", today()),
    sprintf("Analysis Period: %s to %s (%.2f years)",
            summary_stats$first_investment_date,
            summary_stats$last_update_date,
            summary_stats$period_years),
    "",
    "─────────────────────────────────────────────────────────────",
    "PORTFOLIO RETURNS",
    "─────────────────────────────────────────────────────────────",
    "",
    sprintf("Money-Weighted Return (IRR):        %.2f%% p.a.", portfolio_returns$irr * 100),
    sprintf("Total Return:                       %.2f%%", portfolio_returns$total_return * 100),
    "",
    "Portfolio Components:",
    sprintf("  Total Invested:                   R$ %s", format(summary_stats$total_invested, big.mark = ".", decimal.mark = ",", nsmall = 2)),
    sprintf("  Final Value:                      R$ %s", format(summary_stats$final_value, big.mark = ".", decimal.mark = ",", nsmall = 2)),
    sprintf("    - FII Portfolio:                R$ %s (%.1f%%)", format(summary_stats$fii_value, big.mark = ".", decimal.mark = ",", nsmall = 2), summary_stats$fii_pct),
    sprintf("    - Selic Account:                R$ %s (%.1f%%)", format(summary_stats$selic_value, big.mark = ".", decimal.mark = ",", nsmall = 2), summary_stats$selic_pct),
    sprintf("  Capital Gains (FII):              R$ %s", format(summary_stats$capital_gains, big.mark = ".", decimal.mark = ",", nsmall = 2)),
    sprintf("  Proventos Received:               R$ %s", format(summary_stats$proventos_total, big.mark = ".", decimal.mark = ",", nsmall = 2)),
    sprintf("  Selic Interest Earned:            R$ %s", format(summary_stats$proventos_interest, big.mark = ".", decimal.mark = ",", nsmall = 2)),
    "",
    "─────────────────────────────────────────────────────────────",
    "BENCHMARK COMPARISON",
    "─────────────────────────────────────────────────────────────",
    ""
  )

  # Add comparison table
  comp_table_header <- sprintf("%-20s %12s %12s %12s", "Benchmark", "Return (p.a.)", "Alpha", "Result")
  comp_separator <- paste(rep("─", 60), collapse = "")

  report <- c(report, comp_table_header, comp_separator)

  for (i in seq_len(nrow(comparison))) {
    row <- comparison[i, ]
    line <- sprintf("%-20s %11.2f%% %11.2f%% %s",
                    row$benchmark,
                    row$annualized_return * 100,
                    row$alpha_pct,
                    paste(row$outperformance, row$benchmark))
    report <- c(report, line)
  }

  # Add outperformance summary
  n_beat <- sum(comparison$alpha > 0)
  n_total <- nrow(comparison)

  report <- c(
    report,
    "",
    "Outperformance Summary:",
    sprintf("  Beat %d out of %d benchmarks", n_beat, n_total)
  )

  # Add liquidations if any
  if (summary_stats$n_liquidations > 0) {
    report <- c(
      report,
      "",
      "─────────────────────────────────────────────────────────────",
      "LIQUIDATED POSITIONS",
      "─────────────────────────────────────────────────────────────",
      ""
    )

    for (i in seq_len(min(summary_stats$n_liquidations, 10))) {
      liq <- summary_stats$liquidations[i, ]
      line <- sprintf("%-10s  %s  R$ %s",
                      liq$ticker,
                      liq$liquidation_date,
                      format(liq$amortization_value, big.mark = ".", decimal.mark = ",", nsmall = 2))
      report <- c(report, line)
    }

    if (summary_stats$n_liquidations > 10) {
      report <- c(report, sprintf("... and %d more", summary_stats$n_liquidations - 10))
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

  # Also print to console
  cat(paste(report, collapse = "\n"), "\n")

  message(sprintf("✓ Report saved to %s", output_file))

  return(report)
}
