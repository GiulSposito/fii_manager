#' FII Analysis Examples - Usage Guide
#'
#' This script demonstrates how to use the FII analysis framework
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(glue)

# Source all analysis functions
source("./R/analysis/fii_data_sources.R")
source("./R/analysis/fii_indicators.R")
source("./R/analysis/fii_score.R")
source("./R/analysis/fii_comparison.R")

# ============================================================================
# EXAMPLE 1: Analyze a single FII
# ============================================================================

analyze_single_fii <- function(ticker) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("           EXAMPLE 1: Single FII Analysis\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  # Calculate score
  score <- calculate_fii_score(ticker, include_statusinvest = FALSE)

  # Print formatted report
  cat(format_score_report(score))

  return(score)
}

# ============================================================================
# EXAMPLE 2: Batch score portfolio
# ============================================================================

score_portfolio <- function() {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("           EXAMPLE 2: Portfolio Scoring\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  # Score all portfolio FIIs
  scores <- score_multiple_fiis("portfolio", include_statusinvest = FALSE)

  # Print ranking
  print_ranking(scores, top_n = 10)

  # Save results
  saveRDS(scores, "./data/portfolio_scores.rds")
  write_csv(scores, "./data/portfolio_scores.csv")

  cat("\n✅ Results saved to data/portfolio_scores.{rds,csv}\n\n")

  return(scores)
}

# ============================================================================
# EXAMPLE 3: Compare with peers
# ============================================================================

compare_fii_example <- function(ticker) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("           EXAMPLE 3: Peer Comparison\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  comparison <- compare_with_peers(
    ticker,
    peer_method = "segment",
    max_peers = 5,
    include_statusinvest = FALSE
  )

  format_comparison_report(comparison)

  return(comparison)
}

# ============================================================================
# EXAMPLE 4: Segment analysis
# ============================================================================

analyze_segment_example <- function(tipo_fii = "Lajes Corporativas") {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat(glue("      EXAMPLE 4: Segment Analysis - {tipo_fii}\n"))
  cat("═══════════════════════════════════════════════════════════════\n\n")

  scores <- analyze_segment(
    tipo_fii,
    min_patrimonio = 100e6,
    include_statusinvest = FALSE
  )

  # Summary stats
  summary <- segment_summary(scores)

  cat("\n📊 Segment Summary:\n\n")
  print(summary)

  cat("\n\n🏆 Top 10 in Segment:\n\n")
  print_ranking(scores, top_n = 10)

  return(scores)
}

# ============================================================================
# EXAMPLE 5: Portfolio vs Market
# ============================================================================

portfolio_vs_market_example <- function() {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("         EXAMPLE 5: Portfolio vs Market\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  comparison <- portfolio_vs_market(include_statusinvest = FALSE)

  cat("\n📊 PORTFOLIO STATS:\n")
  print(comparison$portfolio_stats)

  cat("\n📊 MARKET STATS (Top 100):\n")
  print(comparison$market_stats)

  cat("\n\n💡 INSIGHTS:\n")

  diff_score <- comparison$portfolio_stats$mean_score -
                comparison$market_stats$mean_score

  if (diff_score > 0) {
    cat(glue("  ✅ Portfolio outperforming market by {round(diff_score, 1)} points\n"))
  } else {
    cat(glue("  ⚠️  Portfolio underperforming market by {round(abs(diff_score), 1)} points\n"))
  }

  diff_dy <- comparison$portfolio_stats$mean_dy -
             comparison$market_stats$mean_dy

  if (diff_dy > 0) {
    cat(glue("  ✅ Portfolio has {round(diff_dy, 2)}% higher average DY\n"))
  } else {
    cat(glue("  ⚠️  Portfolio has {round(abs(diff_dy), 2)}% lower average DY\n"))
  }

  cat("\n")

  return(comparison)
}

# ============================================================================
# EXAMPLE 6: Find best opportunities
# ============================================================================

find_opportunities <- function(min_score = 70,
                                min_dy = 8,
                                max_pvp = 1.0) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("         EXAMPLE 6: Find Investment Opportunities\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  cat(glue("Filters: Score >= {min_score}, DY >= {min_dy}%, P/VP <= {max_pvp}\n\n"))

  cache <- load_cached_data()

  # Get all tickers with recent quotes
  recent_tickers <- cache$quotations %>%
    filter(date >= today() - months(1)) %>%
    pull(ticker) %>%
    unique()

  # Sample (to avoid timeout) - top 200 by recent activity
  sample_tickers <- cache$fiis %>%
    filter(ticker %in% recent_tickers) %>%
    arrange(desc(patrimonio)) %>%
    head(200) %>%
    pull(ticker)

  cat(glue("Analyzing {length(sample_tickers)} FIIs...\n\n"))

  scores <- score_multiple_fiis(sample_tickers, include_statusinvest = FALSE)

  # Apply filters
  opportunities <- scores %>%
    filter(
      total_score >= min_score,
      dy_12m >= min_dy,
      pvp <= max_pvp,
      recommendation %in% c("COMPRAR", "MANTER")
    ) %>%
    arrange(desc(total_score))

  cat(glue("\n✅ Found {nrow(opportunities)} opportunities:\n\n"))

  if (nrow(opportunities) > 0) {
    print_ranking(opportunities, top_n = min(15, nrow(opportunities)))
  } else {
    cat("  No FIIs match all criteria. Try relaxing filters.\n\n")
  }

  return(opportunities)
}

# ============================================================================
# QUICK TEST FUNCTION
# ============================================================================

#' Quick test with a known FII
#'
#' @param ticker FII ticker (default: HGLG11 - common example)
#' @export
quick_test <- function(ticker = "HGLG11") {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("              QUICK TEST - FII Analysis System\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  cat(glue("Testing with {ticker}...\n\n"))

  # Test 1: Single FII analysis
  cat("🧪 Test 1: Single FII Score...\n")
  score <- tryCatch({
    calculate_fii_score(ticker)
  }, error = function(e) {
    cat(glue("  ❌ ERROR: {e$message}\n"))
    return(NULL)
  })

  if (!is.null(score)) {
    cat("  ✅ Score calculation successful\n")
    cat(glue("  📊 Total Score: {score$total_score}/100\n"))
    cat(glue("  📈 Recommendation: {score$recommendation}\n\n"))
  }

  # Test 2: Peer comparison
  cat("🧪 Test 2: Peer Comparison...\n")
  comparison <- tryCatch({
    compare_with_peers(ticker, max_peers = 3)
  }, error = function(e) {
    cat(glue("  ❌ ERROR: {e$message}\n"))
    return(NULL)
  })

  if (!is.null(comparison) && nrow(comparison$peer_scores) > 0) {
    cat("  ✅ Peer comparison successful\n")
    cat(glue("  👥 Found {nrow(comparison$peer_scores)} peers\n\n"))
  }

  # Test 3: Batch scoring (small sample)
  cat("🧪 Test 3: Batch Scoring (3 FIIs)...\n")
  cache <- load_cached_data()
  sample_tickers <- cache$portfolio %>%
    pull(ticker) %>%
    unique() %>%
    head(3)

  batch_scores <- tryCatch({
    score_multiple_fiis(sample_tickers)
  }, error = function(e) {
    cat(glue("  ❌ ERROR: {e$message}\n"))
    return(NULL)
  })

  if (!is.null(batch_scores)) {
    cat("  ✅ Batch scoring successful\n")
    cat(glue("  📊 Scored {nrow(batch_scores)} FIIs\n\n"))
  }

  cat("═══════════════════════════════════════════════════════════════\n")
  cat("                    ✅ ALL TESTS COMPLETED\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  return(list(
    score = score,
    comparison = comparison,
    batch = batch_scores
  ))
}

# ============================================================================
# MAIN DEMO FUNCTION
# ============================================================================

#' Run all examples
#'
#' @export
run_all_examples <- function() {
  cache <- load_cached_data()

  # Pick a ticker from portfolio
  example_ticker <- cache$portfolio %>%
    count(ticker, sort = TRUE) %>%
    head(1) %>%
    pull(ticker)

  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║                                                               ║\n")
  cat("║         FII ANALYSIS FRAMEWORK - COMPLETE DEMO                ║\n")
  cat("║                                                               ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n")

  # Example 1: Single FII
  score1 <- analyze_single_fii(example_ticker)
  Sys.sleep(2)

  # Example 2: Portfolio scoring
  scores2 <- score_portfolio()
  Sys.sleep(2)

  # Example 3: Peer comparison
  comparison3 <- compare_fii_example(example_ticker)
  Sys.sleep(2)

  # Example 4: Segment analysis
  tipo_exemplo <- cache$fiis %>%
    filter(ticker == example_ticker) %>%
    pull(tipo_fii)

  if (length(tipo_exemplo) > 0 && !is.na(tipo_exemplo)) {
    scores4 <- analyze_segment_example(tipo_exemplo)
    Sys.sleep(2)
  }

  # Example 5: Portfolio vs Market
  comparison5 <- portfolio_vs_market_example()
  Sys.sleep(2)

  # Example 6: Opportunities
  opportunities6 <- find_opportunities(
    min_score = 60,
    min_dy = 7,
    max_pvp = 1.1
  )

  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║                                                               ║\n")
  cat("║                 🎉 DEMO COMPLETED! 🎉                         ║\n")
  cat("║                                                               ║\n")
  cat("║  All analysis scripts are working and integrated.            ║\n")
  cat("║  Check data/ folder for saved results.                       ║\n")
  cat("║                                                               ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")
}

# ============================================================================
# USAGE INSTRUCTIONS
# ============================================================================

if (FALSE) {
  # Quick test (recommended first step)
  quick_test()

  # Or test with specific ticker
  quick_test("KNRI11")

  # Run individual examples
  analyze_single_fii("HGLG11")
  score_portfolio()
  compare_fii_example("HGLG11")
  analyze_segment_example("Lajes Corporativas")
  portfolio_vs_market_example()
  find_opportunities(min_score = 70, min_dy = 8, max_pvp = 1.0)

  # Run all examples (takes longer)
  run_all_examples()
}
