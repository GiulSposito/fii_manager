#' FII Comparison - Peer Analysis
#'
#' Functions to compare FIIs using PRE-CALCULATED scores
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(lubridate)
library(glue)

if (file.exists("./R/analysis/fii_analysis.R")) {
  source("./R/analysis/fii_analysis.R", encoding = "UTF-8")
}

# ============================================================================
# PEER COMPARISON
# ============================================================================

#' Compare FII with peers
#'
#' @param ticker Target FII ticker
#' @param max_peers Number of peers (default: 5)
#' @return List with comparison data
#' @export
compare_with_peers <- function(ticker, max_peers = 5) {
  scores <- load_scores_for_analysis()
  cache <- readRDS("data/fiis.rds")

  # Get target info
  target_score <- scores %>% filter(ticker == !!ticker)

  if (nrow(target_score) == 0) {
    stop(glue("No score found for {ticker}"))
  }

  target_type <- target_score$tipo_fii

  # Get peer scores (same segment)
  peer_scores <- scores %>%
    filter(str_detect(tipo_fii, !!target_type),
           ticker != !!ticker) %>%
    arrange(desc(total_score)) %>%
    head(max_peers)

  # Calculate peer statistics
  peer_stats <- peer_scores %>%
    summarise(
      n_peers = n(),
      mean_total_score = mean(total_score, na.rm = TRUE),
      median_total_score = median(total_score, na.rm = TRUE),
      mean_quality = mean(quality, na.rm = TRUE),
      mean_income = mean(income, na.rm = TRUE),
      mean_valuation = mean(valuation, na.rm = TRUE),
      mean_risk = mean(risk, na.rm = TRUE),
      mean_dy = mean(dy_12m, na.rm = TRUE),
      mean_pvp = mean(pvp, na.rm = TRUE)
    )

  # Calculate relative performance
  relative_perf <- tibble(
    metric = c("Total Score", "Quality", "Income", "Valuation", "Risk", "DY 12M", "P/VP"),
    target = c(
      target_score$total_score,
      target_score$quality,
      target_score$income,
      target_score$valuation,
      target_score$risk,
      target_score$dy_12m,
      target_score$pvp
    ),
    peer_mean = c(
      peer_stats$mean_total_score,
      peer_stats$mean_quality,
      peer_stats$mean_income,
      peer_stats$mean_valuation,
      peer_stats$mean_risk,
      peer_stats$mean_dy,
      peer_stats$mean_pvp
    ),
    difference = target - peer_mean,
    better_than_peers = target > peer_mean
  )

  result <- list(
    ticker = ticker,
    target_score = target_score,
    peer_scores = peer_scores,
    peer_stats = peer_stats,
    relative_performance = relative_perf,
    comparison_date = Sys.time()
  )

  return(result)
}

#' Print peer comparison report
#'
#' @param comparison Result from compare_with_peers()
#' @export
print_comparison_report <- function(comparison) {
  target <- comparison$ticker
  target_score <- comparison$target_score$total_score
  peer_mean <- comparison$peer_stats$mean_total_score

  better_metrics <- comparison$relative_performance %>%
    filter(better_than_peers) %>%
    pull(metric)

  worse_metrics <- comparison$relative_performance %>%
    filter(!better_than_peers) %>%
    pull(metric)

  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat(glue("           COMPARATIVE ANALYSIS: {target}\n"))
  cat("═══════════════════════════════════════════════════════════════\n\n")

  cat("📊 Score Comparison:\n")
  cat(glue("  {target}: {round(target_score, 1)}/100\n"))
  cat(glue("  Peer Average: {round(peer_mean, 1)}/100\n"))
  cat(glue("  Difference: {round(target_score - peer_mean, 1)} points\n\n"))

  cat("✅ Better than peers in:\n")
  for (metric in better_metrics) {
    cat(glue("   • {metric}\n"))
  }

  cat("\n⚠️  Worse than peers in:\n")
  for (metric in worse_metrics) {
    cat(glue("   • {metric}\n"))
  }

  cat("\n📈 Detailed Comparison:\n\n")
  print(comparison$relative_performance)

  cat("\n🏆 Peer Ranking:\n\n")
  comparison$peer_scores %>%
    select(ticker, total_score, quality, income, valuation, risk,
           dy_12m, pvp, recommendation) %>%
    print()

  cat("\n")
}

# ============================================================================
# PORTFOLIO VS MARKET
# ============================================================================

#' Compare portfolio against market
#'
#' @export
portfolio_vs_market <- function() {
  scores <- load_scores_for_analysis()
  portfolio <- readRDS("data/portfolio.rds")

  # Portfolio scores
  portfolio_tickers <- unique(portfolio$ticker)
  portfolio_scores <- scores %>%
    filter(ticker %in% portfolio_tickers)

  # Market sample (top 100 by scores)
  market_scores <- scores %>%
    arrange(desc(total_score)) %>%
    head(100)

  # Statistics
  portfolio_stats <- portfolio_scores %>%
    summarise(
      n = n(),
      mean_score = mean(total_score, na.rm = TRUE),
      median_score = median(total_score, na.rm = TRUE),
      mean_dy = mean(dy_12m, na.rm = TRUE),
      mean_pvp = mean(pvp, na.rm = TRUE)
    )

  market_stats <- market_scores %>%
    summarise(
      n = n(),
      mean_score = mean(total_score, na.rm = TRUE),
      median_score = median(total_score, na.rm = TRUE),
      mean_dy = mean(dy_12m, na.rm = TRUE),
      mean_pvp = mean(pvp, na.rm = TRUE)
    )

  result <- list(
    portfolio = portfolio_scores,
    market = market_scores,
    portfolio_stats = portfolio_stats,
    market_stats = market_stats,
    comparison_date = Sys.time()
  )

  return(result)
}

#' Print portfolio vs market report
#'
#' @param comparison Result from portfolio_vs_market()
#' @export
print_portfolio_vs_market <- function(comparison) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("              PORTFOLIO VS MARKET COMPARISON\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  cat("📊 PORTFOLIO STATS:\n")
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
}
