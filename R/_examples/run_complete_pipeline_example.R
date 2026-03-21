#' Example: Running Complete Pipeline v3.0
#'
#' This script demonstrates different usage scenarios for the complete pipeline.
#' Uncomment the scenario you want to run.

library(tidyverse)
library(glue)

# Source the pipeline
source("R/pipeline/main_complete_pipeline.R")

# ===========================================================================
# SCENARIO 1: Quick Daily Update (Portfolio Only)
# ===========================================================================

# Use this for daily monitoring of your portfolio
# Fast execution (2-5 minutes)

# result <- run_complete_analysis(
#   mode = "incremental",        # Incremental updates
#   tickers = "portfolio",       # Only portfolio tickers
#   include_cvm = FALSE,         # Skip CVM (already collected)
#   include_deep_indicators = TRUE,  # Calculate advanced metrics
#   include_analysis = FALSE,    # Skip individual analysis (fast)
#   include_reports = FALSE,     # Skip reports
#   log_level = "INFO"
# )

# ===========================================================================
# SCENARIO 2: Weekly Full Refresh (All FIIs)
# ===========================================================================

# Use this for weekly comprehensive update
# Moderate execution (10-20 minutes depending on number of FIIs)

# result <- run_complete_analysis(
#   mode = "full",               # Full refresh
#   tickers = "all",             # All available FIIs
#   include_cvm = FALSE,         # Skip CVM (monthly only)
#   include_deep_indicators = TRUE,  # Advanced indicators
#   include_analysis = FALSE,    # Skip analysis (can do separately)
#   include_reports = FALSE,     # Skip reports
#   log_level = "INFO"
# )

# ===========================================================================
# SCENARIO 3: Monthly Deep Analysis with Reports
# ===========================================================================

# Use this once a month for comprehensive analysis
# Longer execution (30+ minutes)

# result <- run_complete_analysis(
#   mode = "full",               # Full refresh
#   tickers = "all",             # All FIIs
#   include_cvm = TRUE,          # Collect CVM data (monthly)
#   include_deep_indicators = TRUE,  # Advanced indicators
#   include_analysis = TRUE,     # Individual FII analysis
#   include_reports = TRUE,      # Generate markdown reports
#   log_level = "INFO"
# )

# ===========================================================================
# SCENARIO 4: Custom Analysis for Specific FIIs
# ===========================================================================

# Use this to deeply analyze specific FIIs you're interested in
# Fast execution (1-5 minutes)

result <- run_complete_analysis(
  mode = "incremental",
  tickers = c("KNRI11", "MXRF11", "VISC11"),  # Specific tickers
  include_cvm = TRUE,          # Include CVM data
  include_deep_indicators = TRUE,
  include_analysis = TRUE,     # Deep analysis for these FIIs
  include_reports = TRUE,      # Generate reports
  log_level = "INFO"
)

# ===========================================================================
# POST-EXECUTION: Explore Results
# ===========================================================================

# Check overall success
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("RESULTS SUMMARY\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

cat(glue("Overall Success: {result$summary$overall_success}\n"))
cat(glue("Duration: {round(result$summary$total_duration_secs, 1)}s\n"))
cat(glue("Completed Phases: {paste(result$summary$completed_phases, collapse=', ')}\n"))

if (length(result$summary$failed_phases) > 0) {
  cat(glue("Failed Phases: {paste(result$summary$failed_phases, collapse=', ')}\n"))
}

# Load enriched scores
cat("\n📊 Loading enriched scores...\n")
scores <- if (file.exists("data/fii_scores_enriched.rds")) {
  readRDS("data/fii_scores_enriched.rds")
} else {
  readRDS("data/fii_scores.rds")
}

cat(glue("Loaded {nrow(scores)} FIIs with {ncol(scores)} indicators\n"))

# Show top 10 by score
cat("\n🏆 TOP 10 FIIs by Score:\n\n")
top_fiis <- scores %>%
  arrange(desc(total_score)) %>%
  head(10) %>%
  select(ticker, total_score, recommendation, dy_12m, pvp, vacancia) %>%
  mutate(
    dy_12m = round(dy_12m, 2),
    pvp = round(pvp, 2),
    vacancia = round(vacancia, 1)
  )

print(top_fiis, n = 10)

# Show buy recommendations
cat("\n💰 BUY Recommendations:\n\n")
buy_recs <- scores %>%
  filter(recommendation == "COMPRAR") %>%
  arrange(desc(total_score)) %>%
  select(ticker, total_score, dy_12m, pvp)

cat(glue("{nrow(buy_recs)} FIIs with COMPRAR recommendation\n\n"))
if (nrow(buy_recs) > 0) {
  print(head(buy_recs, 10), n = 10)
}

# Show deep indicators (if available)
if ("alavancagem" %in% names(scores)) {
  cat("\n🔬 Deep Indicators Sample:\n\n")

  deep_sample <- scores %>%
    filter(!is.na(alavancagem)) %>%
    head(5) %>%
    select(ticker, alavancagem, estabilidade_patrimonio, zscore_dy, momentum_12m)

  print(deep_sample, n = 5)
}

# Analysis results (if available)
if (!is.null(result$phase_results$analysis)) {
  analysis_result <- result$phase_results$analysis

  if (!is.null(analysis_result$num_success)) {
    cat(glue("\n📈 Individual Analyses: {analysis_result$num_success} completed\n"))

    if (!is.null(analysis_result$output_file)) {
      cat(glue("   Saved to: {analysis_result$output_file}\n"))
    }
  }
}

# Report results (if available)
if (!is.null(result$phase_results$report)) {
  report_result <- result$phase_results$report

  if (!is.null(report_result$num_reports)) {
    cat(glue("\n📄 Reports: {report_result$num_reports} generated\n"))
    cat(glue("   Location: {report_result$reports_dir}\n"))

    # List first few reports
    if (!is.null(report_result$report_paths)) {
      report_files <- names(report_result$report_paths)
      cat("\n   Reports:\n")
      for (i in seq_len(min(5, length(report_files)))) {
        cat(glue("     - {report_files[i]}\n"))
      }
      if (length(report_files) > 5) {
        cat(glue("     ... and {length(report_files) - 5} more\n"))
      }
    }
  }
}

# Next steps
cat("\n═══════════════════════════════════════════════════════════════\n")
cat("NEXT STEPS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

cat("1. Explore enriched scores:\n")
cat("   scores <- readRDS('data/fii_scores_enriched.rds')\n")
cat("   View(scores)\n\n")

cat("2. Run specific analysis:\n")
cat("   source('R/analysis/fii_opportunities.R')\n")
cat("   opportunities <- identify_opportunities(scores)\n\n")

cat("3. Generate dashboard:\n")
cat("   rmarkdown::render('R/dashboard/portfolio.Rmd')\n\n")

if (!is.null(result$phase_results$report) &&
    !is.null(result$phase_results$report$reports_dir)) {
  cat("4. View reports:\n")
  cat(glue("   Open: {result$phase_results$report$reports_dir}\n\n"))
}

cat("5. Check logs:\n")
cat("   Log file: ")
if (!is.null(result$phase_results$import)) {
  cat("data/.logs/pipeline_*.log\n")
} else {
  cat("(check data/.logs/)\n")
}

cat("\n")
