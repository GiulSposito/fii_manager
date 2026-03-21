#' Test script for FII Opportunities system
#'
#' Examples of how to use the intelligent opportunity detector
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)

# Source the opportunities module
source("./R/analysis/fii_opportunities.R", encoding = "UTF-8")
source("./R/transform/fii_deep_indicators.R", encoding = "UTF-8")

# ============================================================================
# SETUP: Load and enrich scores
# ============================================================================

cat("Loading scores and enriching with deep indicators...\n")

# Load basic scores
if (!file.exists("data/fii_scores.rds")) {
  stop("Run run_scoring_pipeline() first to generate scores")
}

basic_scores <- readRDS("data/fii_scores.rds")

# Load cache for deep indicators
cache <- load_deep_indicators_cache(
  cvm_file = "data/fii_cvm.rds",
  scores_file = "data/fii_scores.rds",
  fiis_file = "data/fiis.rds",
  history_file = "data/fii_scores_history.rds"
)

# Enrich scores with deep indicators
scores_enriched <- enrich_scores_with_deep_indicators(basic_scores, cache)

cat(glue("\nEnriched scores: {nrow(scores_enriched)} FIIs with {ncol(scores_enriched)} columns\n\n"))

# ============================================================================
# EXAMPLE 1: Advanced Screener
# ============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("EXAMPLE 1: Advanced Multi-Criteria Screener\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Define criteria
criteria <- list(
  total_score = list(min = 70),
  dy_12m = list(min = 0.08, max = 0.15),
  pvp = list(max = 1.0),
  quality = list(min = 60)
)

# Screen for opportunities
opportunities <- find_opportunities_advanced(
  scores_enriched,
  criteria = criteria,
  operator = "AND",
  blacklist = c(),  # Add tickers to exclude if needed
  ranking_weights = c(quality = 0.25, income = 0.35, valuation = 0.25, risk = 0.15)
)

if (nrow(opportunities) > 0) {
  cat("Top 10 opportunities:\n\n")
  print(
    opportunities %>%
      select(ticker, total_score, custom_score, dy_12m, pvp, tipo_fii, recommendation) %>%
      head(10)
  )
} else {
  cat("No opportunities found with these criteria\n")
}

cat("\n")

# ============================================================================
# EXAMPLE 2: Pattern Detection
# ============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("EXAMPLE 2: Pattern Detection\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Mean reversion opportunities
cat("A. Mean Reversion (FIIs below historical P/VP):\n")
mean_rev <- detect_mean_reversion(scores_enriched, window = 12, min_discount_pct = 10)

if (nrow(mean_rev) > 0) {
  print(
    mean_rev %>%
      select(ticker, pvp, pvp_mean, desconto_pct, total_score) %>%
      head(5)
  )
  cat("\n")
} else {
  cat("  No mean reversion opportunities detected\n\n")
}

# Positive momentum
cat("B. Positive Momentum (sustained upward trend):\n")
momentum <- detect_momentum_positivo(scores_enriched, windows = c(3, 6))

if (nrow(momentum) > 0) {
  print(
    momentum %>%
      select(ticker, momentum_3m, momentum_6m, aceleracao, total_score) %>%
      head(5)
  )
  cat("\n")
} else {
  cat("  No positive momentum opportunities detected\n\n")
}

# Value traps
cat("C. Value Traps to AVOID (low P/VP but poor quality):\n")
traps <- detect_value_traps(scores_enriched, pvp_threshold = 0.90, quality_threshold = 50)

if (nrow(traps) > 0) {
  print(
    traps %>%
      select(ticker, pvp, score_qualidade, razao_evitar) %>%
      head(5)
  )
  cat("\n")
} else {
  cat("  No value traps detected\n\n")
}

# ============================================================================
# EXAMPLE 3: Portfolio Alerts
# ============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("EXAMPLE 3: Portfolio Monitoring Alerts\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Load portfolio
if (file.exists("data/portfolio.rds")) {
  portfolio <- readRDS("data/portfolio.rds")
  portfolio_tickers <- unique(portfolio$ticker)

  cat(glue("Monitoring {length(portfolio_tickers)} portfolio holdings...\n\n"))

  # Generate alerts
  alerts <- generate_alerts_portfolio(
    portfolio_tickers,
    scores_enriched,
    scores_history = cache$scores_history,
    thresholds = list(
      vacancia_max = 0.20,
      alavancagem_max = 0.50,
      score_drop = 10,
      dy_drop_pct = 20,
      pvp_spike_pct = 15
    )
  )

  if (nrow(alerts) > 0) {
    print(
      alerts %>%
        select(ticker, tipo_alerta, severidade, mensagem)
    )
    cat("\n")
  } else {
    cat("No alerts - portfolio looks healthy!\n\n")
  }
} else {
  cat("No portfolio data available (data/portfolio.rds not found)\n\n")
}

# ============================================================================
# EXAMPLE 4: Contextual Recommendations
# ============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("EXAMPLE 4: Personalized Recommendations\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Define user profile
user_profile <- list(
  perfil_risco = "moderado",  # "conservador" | "moderado" | "agressivo"
  objetivo = "renda",          # "renda" | "valorizacao" | "hibrido"
  horizonte_anos = 5
)

cat("User profile:\n")
cat(glue("  Risco: {user_profile$perfil_risco}\n"))
cat(glue("  Objetivo: {user_profile$objetivo}\n"))
cat(glue("  Horizonte: {user_profile$horizonte_anos} anos\n\n"))

# Get top ticker to analyze
if (nrow(scores_enriched) > 0) {
  top_ticker <- scores_enriched %>%
    arrange(desc(total_score)) %>%
    slice_head(n = 1) %>%
    pull(ticker)

  cat(glue("Analyzing top opportunity: {top_ticker}\n\n"))

  recommendation <- recommend_actions(
    top_ticker,
    scores_enriched,
    user_profile
  )

  print_recommendation(recommendation)
} else {
  cat("No scores available for recommendations\n\n")
}

# ============================================================================
# EXAMPLE 5: Complete Opportunities Report
# ============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("EXAMPLE 5: Comprehensive Opportunities Report\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Generate complete report
portfolio_tickers <- if (file.exists("data/portfolio.rds")) {
  unique(readRDS("data/portfolio.rds")$ticker)
} else {
  NULL
}

complete_report <- generate_opportunities_report(
  scores_enriched,
  portfolio_tickers = portfolio_tickers,
  user_profile = user_profile,
  top_n = 10
)

print_opportunities_report(complete_report)

# ============================================================================
# Save report for later analysis
# ============================================================================

report_file <- glue("data/opportunities_report_{format(Sys.Date(), '%Y%m%d')}.rds")
saveRDS(complete_report, report_file)
cat(glue("\nReport saved to: {report_file}\n"))

cat("\n✅ All examples completed successfully!\n\n")
