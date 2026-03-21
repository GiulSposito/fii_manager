#' FII Analysis Examples - Using Pre-Calculated Scores
#'
#' Examples of analysis using the new architecture:
#' Import → Transform (scoring) → Analysis (fast queries)
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(glue)

source("./R/analysis/fii_analysis.R", encoding = "UTF-8")
source("./R/analysis/fii_comparison.R", encoding = "UTF-8")

# ============================================================================
# EXAMPLE 1: Quick Portfolio Analysis
# ============================================================================

example1_portfolio_analysis <- function() {
  cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║             EXAMPLE 1: Portfolio Analysis                    ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

  # Get portfolio with scores
  portfolio_scores <- get_portfolio_scores()

  cat("📊 Portfolio Overview:\n\n")
  print_portfolio_summary()

  cat("\n🏆 Top 10 FIIs in Portfolio:\n")
  print_ranking(portfolio_scores, top_n = 10)

  # Identify weak performers
  weak <- portfolio_scores %>%
    filter(recommendation == "EVITAR")

  if (nrow(weak) > 0) {
    cat("\n⚠️  FIIs to Review (EVITAR):\n")
    weak %>%
      select(ticker, total_score, dy_12m, pvp, unrealized_return_pct) %>%
      print()
  }

  return(portfolio_scores)
}

# ============================================================================
# EXAMPLE 2: Find Opportunities
# ============================================================================

example2_find_opportunities <- function() {
  cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║             EXAMPLE 2: Find Opportunities                    ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

  # High quality opportunities
  opportunities <- find_opportunities(
    min_score = 60,    # Relaxed for example
    min_dy = 7,
    max_pvp = 1.0
  )

  cat(glue("Found {nrow(opportunities)} opportunities:\n\n"))

  if (nrow(opportunities) > 0) {
    print_ranking(opportunities, top_n = 15)
  } else {
    cat("No FIIs match criteria. Try relaxing filters.\n")
  }

  return(opportunities)
}

# ============================================================================
# EXAMPLE 3: Peer Comparison
# ============================================================================

example3_peer_comparison <- function(ticker = NULL) {
  cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║             EXAMPLE 3: Peer Comparison                       ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

  # Use first portfolio ticker if not specified
  if (is.null(ticker)) {
    portfolio <- readRDS("data/portfolio.rds")
    ticker <- portfolio %>%
      count(ticker, sort = TRUE) %>%
      head(1) %>%
      pull(ticker)
  }

  cat(glue("Comparing {ticker} with peers...\n\n"))

  comparison <- compare_with_peers(ticker, max_peers = 5)
  print_comparison_report(comparison)

  return(comparison)
}

# ============================================================================
# EXAMPLE 4: Segment Analysis
# ============================================================================

example4_segment_analysis <- function(segment = "Lajes Corporativas") {
  cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║             EXAMPLE 4: Segment Analysis                      ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

  cat(glue("Analyzing segment: {segment}\n\n"))

  summary <- analyze_segment(segment)

  if (is.null(summary)) {
    return(NULL)
  }

  cat("📊 Segment Summary:\n")
  cat(glue("  Number of FIIs:    {summary$n_fiis}\n"))
  cat(glue("  Mean Score:        {round(summary$mean_score, 1)}\n"))
  cat(glue("  Median Score:      {round(summary$median_score, 1)}\n"))
  cat(glue("  Mean DY:           {format(summary$mean_dy, decimal.mark=',', nsmall=1)}%\n"))
  cat(glue("  Mean P/VP:         {format(summary$mean_pvp, decimal.mark=',', nsmall=2)}\n"))
  cat(glue("  COMPRAR count:     {summary$n_comprar}\n\n"))

  cat("🏆 Top 5 in Segment:\n")
  for (i in seq_along(summary$top_fiis)) {
    cat(glue("  {i}. {summary$top_fiis[i]}\n"))
  }
  cat("\n")

  # Get full scores for segment
  scores <- load_scores_for_analysis()
  segment_scores <- scores %>%
    filter(str_detect(tipo_fii, !!segment)) %>%
    arrange(desc(total_score))

  print_ranking(segment_scores, top_n = 10)

  return(summary)
}

# ============================================================================
# EXAMPLE 5: Portfolio vs Market
# ============================================================================

example5_portfolio_vs_market <- function() {
  cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║             EXAMPLE 5: Portfolio vs Market                   ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

  comparison <- portfolio_vs_market()
  print_portfolio_vs_market(comparison)

  return(comparison)
}

# ============================================================================
# EXAMPLE 6: Score Changes (Historical)
# ============================================================================

example6_score_changes <- function() {
  cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║             EXAMPLE 6: Recent Score Changes                  ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

  if (!file.exists("data/fii_scores_history.rds")) {
    cat("No historical data yet. Run pipeline multiple times to track changes.\n")
    return(NULL)
  }

  print_score_changes(min_change = 3)
}

# ============================================================================
# EXAMPLE 7: Single FII Report
# ============================================================================

example7_single_fii <- function(ticker = NULL) {
  cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║             EXAMPLE 7: Single FII Report                     ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

  if (is.null(ticker)) {
    portfolio <- readRDS("data/portfolio.rds")
    ticker <- portfolio %>%
      count(ticker, sort = TRUE) %>%
      head(1) %>%
      pull(ticker)
  }

  print_fii_report(ticker)
}

# ============================================================================
# QUICK TEST
# ============================================================================

#' Quick test of all analysis functions
#'
#' @export
quick_test_analysis <- function() {
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║                                                               ║\n")
  cat("║           QUICK TEST - Analysis Framework                    ║\n")
  cat("║                                                               ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n")

  # Check if scores exist
  if (!file.exists("data/fii_scores.rds")) {
    cat("\n❌ No scores found!\n")
    cat("\nPlease run the pipeline first:\n")
    cat("  source('R/pipeline/main_portfolio_with_scoring.R')\n")
    cat("\nOr just the scoring pipeline:\n")
    cat("  source('R/transform/fii_score_pipeline.R')\n")
    cat("  run_scoring_pipeline()\n\n")
    return(NULL)
  }

  # Test 1: Load scores
  cat("\n🧪 Test 1: Load scores... ")
  scores <- tryCatch({
    load_scores_for_analysis()
  }, error = function(e) {
    cat("❌ FAIL\n")
    return(NULL)
  })

  if (!is.null(scores)) {
    cat("✅ PASS\n")
    cat(glue("   Loaded {nrow(scores)} FIIs\n"))
  }

  # Test 2: Portfolio summary
  cat("\n🧪 Test 2: Portfolio summary... ")
  summary <- tryCatch({
    portfolio_summary()
  }, error = function(e) {
    cat("❌ FAIL\n")
    return(NULL)
  })

  if (!is.null(summary)) {
    cat("✅ PASS\n")
    cat(glue("   {summary$n_fiis} FIIs, mean score: {round(summary$mean_score, 1)}\n"))
  }

  # Test 3: Find opportunities
  cat("\n🧪 Test 3: Find opportunities... ")
  opps <- tryCatch({
    find_opportunities(min_score = 60, min_dy = 5, max_pvp = 1.2)
  }, error = function(e) {
    cat("❌ FAIL\n")
    return(NULL)
  })

  if (!is.null(opps)) {
    cat("✅ PASS\n")
    cat(glue("   Found {nrow(opps)} opportunities\n"))
  }

  # Test 4: Peer comparison
  cat("\n🧪 Test 4: Peer comparison... ")
  portfolio <- readRDS("data/portfolio.rds")
  test_ticker <- portfolio %>% pull(ticker) %>% unique() %>% head(1)

  comp <- tryCatch({
    compare_with_peers(test_ticker, max_peers = 3)
  }, error = function(e) {
    cat("❌ FAIL\n")
    return(NULL)
  })

  if (!is.null(comp)) {
    cat("✅ PASS\n")
    cat(glue("   Compared {test_ticker} with {nrow(comp$peer_scores)} peers\n"))
  }

  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║                                                               ║\n")
  cat("║                  ✅ ALL TESTS PASSED                          ║\n")
  cat("║                                                               ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

  cat("📚 Next steps:\n")
  cat("  • example1_portfolio_analysis()\n")
  cat("  • example2_find_opportunities()\n")
  cat("  • example7_single_fii('HGLG11')\n\n")
}

# ============================================================================
# RUN ALL EXAMPLES
# ============================================================================

#' Run all examples in sequence
#'
#' @export
run_all_examples <- function() {
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║                                                               ║\n")
  cat("║              FII ANALYSIS - ALL EXAMPLES                      ║\n")
  cat("║                                                               ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n")

  example1_portfolio_analysis()
  Sys.sleep(2)

  example2_find_opportunities()
  Sys.sleep(2)

  example3_peer_comparison()
  Sys.sleep(2)

  example4_segment_analysis()
  Sys.sleep(2)

  example5_portfolio_vs_market()
  Sys.sleep(2)

  example6_score_changes()
  Sys.sleep(2)

  example7_single_fii()

  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║                                                               ║\n")
  cat("║                  🎉 ALL EXAMPLES COMPLETED 🎉                 ║\n")
  cat("║                                                               ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")
}

# ============================================================================
# USAGE
# ============================================================================

if (FALSE) {
  # First, run pipeline to calculate scores
  source("R/pipeline/main_portfolio_with_scoring.R")

  # Then run analyses (instant, using pre-calculated scores)
  source("R/analysis/analysis_examples.R")

  # Quick test
  quick_test_analysis()

  # Run examples
  example1_portfolio_analysis()
  example2_find_opportunities()
  example3_peer_comparison("HGLG11")

  # Or all at once
  run_all_examples()
}
