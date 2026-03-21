#' Main Portfolio Pipeline with Scoring
#'
#' Complete pipeline: Import → Transform (scoring) → Ready for Analysis
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(lubridate)
library(glue)

# ============================================================================
# IMPORT LAYER
# ============================================================================

message("╔═══════════════════════════════════════════════════════════════╗")
message("║                                                               ║")
message("║         MAIN PORTFOLIO PIPELINE (with Scoring)               ║")
message("║                                                               ║")
message("╚═══════════════════════════════════════════════════════════════╝\n")

message("📦 PHASE 1: IMPORT (Data Collection)")
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

# 1.1 Portfolio from Google Sheets
message("1/4 Importing portfolio from Google Sheets...")
source("./R/import/portfolioGoogleSheets.R")
portfolio <- tryCatch({
  updatePortfolio()
}, error = function(e) {
  message("  ⚠️  Failed: ", e$message)
  readRDS("./data/portfolio.rds")  # Use cache
})
message(glue("  ✓ Loaded {nrow(portfolio)} transactions ({length(unique(portfolio$ticker))} tickers)\n"))

# 1.2 Price Quotes
message("2/4 Fetching price quotes from Yahoo Finance...")
source("./R/import/pricesYahoo.R")
prices <- tryCatch({
  updatePortfolioPrices(portfolio)
}, error = function(e) {
  message("  ⚠️  Failed: ", e$message)
  readRDS("./data/quotations.rds")  # Use cache
})
message(glue("  ✓ Updated quotes\n"))

# 1.3 Income/Proventos
message("3/4 Scraping income distributions...")
source("./R/import/proventos.R")
proventos <- tryCatch({
  updateProventos(portfolio)
}, error = function(e) {
  message("  ⚠️  Failed: ", e$message)
  readRDS("./data/income.rds")  # Use cache
})
message(glue("  ✓ Updated proventos\n"))

# 1.4 Market Data (Lupa)
message("4/4 Importing market data from fiis.com.br...")
source("./R/api/import_lupa_2023.R")
fiis_data <- tryCatch({
  importLupa()
}, error = function(e) {
  message("  ⚠️  Failed: ", e$message)
  readRDS("./data/fiis.rds")  # Use cache
})
message(glue("  ✓ Loaded {nrow(fiis_data)} FIIs data\n"))

message("\n✅ PHASE 1 COMPLETE: All data imported\n")

# ============================================================================
# TRANSFORM LAYER (SCORING)
# ============================================================================

message("\n🔄 PHASE 2: TRANSFORM (Score Calculation)")
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

source("./R/transform/fii_score_pipeline.R")

# Run scoring pipeline
scores <- run_scoring_pipeline(
  tickers = "all",              # Score all available FIIs
  include_statusinvest = FALSE,  # Fast mode (cache only)
  force = FALSE                  # Skip if recent
)

message("\n✅ PHASE 2 COMPLETE: Scores calculated and saved\n")

# ============================================================================
# SUMMARY
# ============================================================================

message("\n📊 PIPELINE SUMMARY")
message("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

message("Data files updated:")
message("  • data/portfolio.rds         (raw data)")
message("  • data/quotations.rds        (raw data)")
message("  • data/income.rds            (raw data)")
message("  • data/fiis.rds              (raw data)")
message("  • data/fii_scores.rds        (transformed) ← NEW!")
message("  • data/fii_scores.csv        (transformed) ← NEW!")
message("  • data/fii_scores_history.rds (tracking)  ← NEW!")

message("\n📈 Next steps:")
message("  • Run analysis scripts in R/analysis/")
message("  • Load scores: scores <- readRDS('data/fii_scores.rds')")
message("  • Or use: source('R/analysis/fii_analysis.R')")

message("\n╔═══════════════════════════════════════════════════════════════╗")
message("║                                                               ║")
message("║                  ✅ PIPELINE COMPLETED                        ║")
message("║                                                               ║")
message("╚═══════════════════════════════════════════════════════════════╝\n")
