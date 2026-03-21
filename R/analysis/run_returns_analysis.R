#' Portfolio Returns Analysis - Main Orchestrator
#'
#' Complete pipeline for analyzing portfolio returns with benchmark comparison
#' considering proventos reinvested in Selic
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)

# Source dependencies
source("R/import/benchmark_data.R")
source("R/analysis/selic_reinvestment.R")
source("R/analysis/portfolio_returns.R")
source("R/analysis/benchmark_comparison.R")
source("R/analysis/strategy_comparison.R")

#' Main analysis pipeline
#'
#' Orchestrates complete return analysis:
#' 1. Update benchmark data
#' 2. Calculate portfolio returns (IRR)
#' 3. Compare with benchmarks
#' 4. Generate reports and visualizations
#'
#' @param update_benchmarks logical Whether to update benchmark data (default: TRUE)
#' @param export_csv logical Whether to export CSV files (default: TRUE)
#' @param save_plots logical Whether to save plots (default: TRUE)
#' @param output_dir Character Output directory for reports (default: /tmp)
#' @return list with all analysis results
run_returns_analysis <- function(update_benchmarks = TRUE,
                                  export_csv = TRUE,
                                  save_plots = TRUE,
                                  output_dir = "/tmp") {

  message("╔═══════════════════════════════════════════════════════════╗")
  message("║                                                           ║")
  message("║     PORTFOLIO RETURN ANALYSIS WITH BENCHMARKS v1.0       ║")
  message("║                                                           ║")
  message("╚═══════════════════════════════════════════════════════════╝")
  message("")

  start_time <- Sys.time()

  # =================================================================
  # PHASE 1: DATA PREPARATION
  # =================================================================

  message("PHASE 1: DATA PREPARATION")
  message("─────────────────────────────────────────────────────────────")
  message("")

  # Load portfolio to get start date
  portfolio <- readRDS("data/portfolio.rds")
  portfolio_start_date <- min(portfolio$date)

  message(sprintf("Portfolio start date: %s", portfolio_start_date))
  message(sprintf("Portfolio transactions: %d", nrow(portfolio)))
  message(sprintf("Unique tickers: %d", n_distinct(portfolio$ticker)))
  message("")

  # Update benchmarks if requested
  if (update_benchmarks) {
    message("Updating benchmark data...")
    benchmarks <- update_all_benchmarks(portfolio_start_date = portfolio_start_date)
  } else {
    message("Loading cached benchmark data...")
    benchmarks <- load_benchmarks()
  }
  message("")

  # =================================================================
  # PHASE 2: PORTFOLIO RETURN CALCULATION
  # =================================================================

  message("PHASE 2: PORTFOLIO RETURN CALCULATION")
  message("─────────────────────────────────────────────────────────────")
  message("")

  portfolio_returns <- calculate_all_returns(
    portfolio_path = "data/portfolio.rds",
    income_path = "data/income.rds",
    prices_path = "data/quotations.rds",
    benchmarks_path = "data/benchmarks.rds"
  )

  message("")

  # =================================================================
  # PHASE 3: BENCHMARK COMPARISON
  # =================================================================

  message("PHASE 3: BENCHMARK COMPARISON")
  message("─────────────────────────────────────────────────────────────")
  message("")

  # Calculate benchmark returns
  benchmark_returns <- calculate_benchmark_returns(
    benchmarks = benchmarks,
    start_date = portfolio_start_date,
    end_date = today()
  )

  # Compare portfolio with benchmarks
  comparison <- compare_with_benchmarks(
    portfolio_returns = portfolio_returns,
    benchmark_returns = benchmark_returns
  )

  # Generate summary statistics
  summary_stats <- generate_summary_statistics(
    portfolio_returns = portfolio_returns,
    benchmarks = benchmarks
  )

  # Strategy comparison
  strategy_comparison <- compare_strategy_vs_benchmarks(
    portfolio_returns = portfolio_returns,
    benchmarks = benchmarks,
    start_date = portfolio_start_date
  )

  message("")

  # =================================================================
  # PHASE 4: REPORTING AND VISUALIZATION
  # =================================================================

  message("PHASE 4: REPORTING AND VISUALIZATION")
  message("─────────────────────────────────────────────────────────────")
  message("")

  # Generate text report
  report_file <- file.path(output_dir, "portfolio_returns_report.txt")
  report <- generate_comparison_report(
    portfolio_returns = portfolio_returns,
    comparison = comparison,
    summary_stats = summary_stats,
    output_file = report_file
  )

  # Generate strategy comparison report
  strategy_report_file <- file.path(output_dir, "strategy_comparison.txt")
  strategy_report <- generate_strategy_report(
    comparison = strategy_comparison,
    output_file = strategy_report_file
  )

  # Export CSV files
  if (export_csv) {
    message("Exporting CSV files...")

    # Comparison table
    comparison_file <- file.path(output_dir, "benchmark_comparison.csv")
    comparison %>%
      select(benchmark, total_return, annualized_return, alpha, alpha_pct) %>%
      write_csv(comparison_file)
    message(sprintf("  ✓ %s", comparison_file))

    # Strategy comparison
    strategy_file <- file.path(output_dir, "strategy_comparison.csv")
    strategy_comparison %>%
      write_csv(strategy_file)
    message(sprintf("  ✓ %s", strategy_file))

    # Liquidations (if any)
    if (nrow(portfolio_returns$liquidations) > 0) {
      liquidations_file <- file.path(output_dir, "liquidated_positions.csv")
      portfolio_returns$liquidations %>%
        write_csv(liquidations_file)
      message(sprintf("  ✓ %s", liquidations_file))
    }

    # Cash flows
    cashflows_file <- file.path(output_dir, "portfolio_cashflows.csv")
    portfolio_returns$cash_flows %>%
      write_csv(cashflows_file)
    message(sprintf("  ✓ %s", cashflows_file))

    # Selic account timeline (sample - every 30 days to avoid huge file)
    selic_timeline_file <- file.path(output_dir, "selic_account_timeline.csv")
    portfolio_returns$selic_account$timeline %>%
      filter(row_number() %% 30 == 1 | row_number() == n()) %>%  # Sample every 30 days
      write_csv(selic_timeline_file)
    message(sprintf("  ✓ %s", selic_timeline_file))

    message("")
  }

  # Generate plots
  if (save_plots) {
    message("Generating visualizations...")

    # Cumulative returns plot
    plot_cumulative <- plot_cumulative_returns(
      portfolio_returns = portfolio_returns,
      benchmarks = benchmarks,
      start_date = portfolio_start_date
    )

    plot_file <- file.path(output_dir, "portfolio_vs_benchmarks.png")
    ggsave(plot_file, plot_cumulative, width = 12, height = 6, dpi = 300)
    message(sprintf("  ✓ %s", plot_file))

    # Selic account evolution plot
    plot_selic <- plot_selic_account(portfolio_returns$selic_account)
    selic_plot_file <- file.path(output_dir, "selic_account_evolution.png")
    ggsave(selic_plot_file, plot_selic, width = 10, height = 6, dpi = 300)
    message(sprintf("  ✓ %s", selic_plot_file))

    message("")
  }

  # =================================================================
  # SAVE COMPLETE RESULTS
  # =================================================================

  results <- list(
    portfolio_returns = portfolio_returns,
    benchmark_returns = benchmark_returns,
    comparison = comparison,
    strategy_comparison = strategy_comparison,
    summary_stats = summary_stats,
    benchmarks = benchmarks,
    analysis_date = today(),
    runtime = as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  )

  results_file <- "data/portfolio_returns_analysis.rds"
  saveRDS(results, results_file)
  message(sprintf("✓ Complete results saved to %s", results_file))
  message("")

  # =================================================================
  # FINAL SUMMARY
  # =================================================================

  message("╔═══════════════════════════════════════════════════════════╗")
  message("║                   ANALYSIS COMPLETE                       ║")
  message("╚═══════════════════════════════════════════════════════════╝")
  message("")
  message("KEY RESULTS:")
  message(sprintf("  IRR (Money-Weighted Return): %.2f%% p.a.", results$portfolio_returns$irr * 100))
  message(sprintf("  Total Return: %.2f%%", results$portfolio_returns$total_return * 100))
  message(sprintf("  Outperformed: %d / %d benchmarks",
                  sum(results$comparison$alpha > 0),
                  nrow(results$comparison)))
  message("")
  message(sprintf("  Total Invested: R$ %s",
                  format(results$summary_stats$total_invested, big.mark = ".", decimal.mark = ",", nsmall = 2)))
  message(sprintf("  Final Value: R$ %s",
                  format(results$summary_stats$final_value, big.mark = ".", decimal.mark = ",", nsmall = 2)))
  message("")
  message(sprintf("Runtime: %.1f seconds", results$runtime))
  message("")
  message("Output files:")
  message(sprintf("  Report: %s", report_file))
  if (export_csv) {
    message(sprintf("  CSVs: %s/", output_dir))
  }
  if (save_plots) {
    message(sprintf("  Plots: %s/", output_dir))
  }
  message("")
  message("╚═══════════════════════════════════════════════════════════╝")

  return(invisible(results))
}

# =================================================================
# CONVENIENCE FUNCTIONS
# =================================================================

#' Quick analysis run with defaults
#'
#' Runs complete analysis with all defaults
#'
#' @export
quick_analysis <- function() {
  run_returns_analysis(
    update_benchmarks = TRUE,
    export_csv = TRUE,
    save_plots = TRUE
  )
}

#' Re-run analysis with cached benchmarks
#'
#' Useful for iterative development - skips benchmark update
#'
#' @export
rerun_analysis <- function() {
  run_returns_analysis(
    update_benchmarks = FALSE,
    export_csv = TRUE,
    save_plots = TRUE
  )
}

#' Print last analysis summary
#'
#' Loads and prints summary of most recent analysis
#'
#' @export
print_last_analysis <- function() {
  if (!file.exists("data/portfolio_returns_analysis.rds")) {
    message("No previous analysis found. Run run_returns_analysis() first.")
    return(invisible(NULL))
  }

  results <- readRDS("data/portfolio_returns_analysis.rds")

  message("")
  message("═══════════════════════════════════════════════════════════")
  message("    LAST ANALYSIS SUMMARY")
  message("═══════════════════════════════════════════════════════════")
  message(sprintf("Analysis Date: %s", results$analysis_date))
  message("")
  message("PORTFOLIO RETURNS:")
  message(sprintf("  IRR: %.2f%% p.a.", results$portfolio_returns$irr * 100))
  message(sprintf("  Total Return: %.2f%%", results$portfolio_returns$total_return * 100))
  message("")
  message("VS BENCHMARKS:")

  results$comparison %>%
    select(benchmark, annualized_return, alpha_pct, outperformance) %>%
    mutate(
      annualized_return = sprintf("%.2f%%", annualized_return * 100),
      alpha_pct = sprintf("%+.2f%%", alpha_pct)
    ) %>%
    print(n = Inf)

  message("═══════════════════════════════════════════════════════════")
  message("")

  return(invisible(results))
}

# =================================================================
# MAIN EXECUTION (if sourced directly)
# =================================================================

if (interactive()) {
  message("")
  message("Portfolio Returns Analysis - Main Script Loaded")
  message("")
  message("Available functions:")
  message("  run_returns_analysis()  - Complete analysis with options")
  message("  quick_analysis()        - Quick run with all defaults")
  message("  rerun_analysis()        - Re-run with cached benchmarks")
  message("  print_last_analysis()   - Show last analysis summary")
  message("")
  message("Example: quick_analysis()")
  message("")
}
