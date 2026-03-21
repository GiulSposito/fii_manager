#' FII Analysis - Analysis Layer
#'
#' High-level analysis functions that use PRE-CALCULATED scores
#' from the transform layer (data/fii_scores.rds)
#'
#' Pipeline architecture:
#'   Import → Transform (scores calculated) → Analysis (uses scores) ← THIS
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(lubridate)
library(glue)

# Load transform layer functions (for pipeline access if needed)
if (file.exists("./R/transform/fii_score_pipeline.R")) {
  source("./R/transform/fii_score_pipeline.R", encoding = "UTF-8")
}

# ============================================================================
# CORE ANALYSIS FUNCTIONS
# ============================================================================

#' Load and validate scores
#'
#' @param auto_refresh Auto-refresh if stale (default: FALSE)
#' @return Scores tibble
load_scores_for_analysis <- function(auto_refresh = FALSE) {
  scores <- load_scores(max_age_hours = 24, auto_refresh = auto_refresh)

  # Validate
  if (nrow(scores) == 0) {
    stop("No scores available. Run run_scoring_pipeline() first.")
  }

  return(scores)
}

#' Get portfolio scores with positions
#'
#' @return Tibble with scores + portfolio positions
#' @export
get_portfolio_scores <- function() {
  scores <- load_scores_for_analysis()
  portfolio <- readRDS("data/portfolio.rds")

  # Aggregate portfolio positions
  positions <- portfolio %>%
    group_by(ticker) %>%
    summarise(
      shares = sum(volume),
      invested = sum(value),
      avg_price = weighted.mean(price, volume),
      first_buy = min(date),
      last_buy = max(date)
    )

  # Join with scores
  portfolio_scores <- scores %>%
    inner_join(positions, by = "ticker") %>%
    mutate(
      current_value = shares * current_price,
      unrealized_gain = current_value - invested,
      unrealized_return_pct = (unrealized_gain / invested) * 100
    ) %>%
    arrange(desc(total_score))

  return(portfolio_scores)
}

#' Rank FIIs by score
#'
#' @param filter_expr Optional filter expression (e.g., "tipo_fii == 'Logística'")
#' @param top_n Number of top FIIs to return (default: all)
#' @return Ranked tibble
#' @export
rank_fiis <- function(filter_expr = NULL, top_n = NULL) {
  scores <- load_scores_for_analysis()

  if (!is.null(filter_expr)) {
    scores <- scores %>% filter(eval(parse(text = filter_expr)))
  }

  ranked <- scores %>%
    arrange(desc(total_score)) %>%
    mutate(rank = row_number())

  if (!is.null(top_n)) {
    ranked <- ranked %>% head(top_n)
  }

  return(ranked)
}

#' Find investment opportunities
#'
#' @param min_score Minimum total score (default: 70)
#' @param min_dy Minimum dividend yield % (default: 8)
#' @param max_pvp Maximum P/VP ratio (default: 1.0)
#' @param tipo_fii Optional FII type filter
#' @return Tibble with opportunities
#' @export
find_opportunities <- function(min_score = 70,
                                min_dy = 8,
                                max_pvp = 1.0,
                                tipo_fii = NULL) {
  scores <- load_scores_for_analysis()

  opportunities <- scores %>%
    filter(
      total_score >= min_score,
      dy_12m >= min_dy,
      pvp <= max_pvp,
      recommendation %in% c("COMPRAR", "MANTER")
    )

  if (!is.null(tipo_fii)) {
    opportunities <- opportunities %>%
      filter(str_detect(tipo_fii, !!tipo_fii))
  }

  opportunities <- opportunities %>%
    arrange(desc(total_score))

  return(opportunities)
}

#' Print formatted ranking
#'
#' @param scores_df Scores tibble
#' @param top_n Number to display (default: 10)
#' @export
print_ranking <- function(scores_df, top_n = 10) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("                 FII RANKING - TOP", top_n, "\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  scores_df %>%
    head(top_n) %>%
    mutate(
      rank = row_number(),
      icon = case_when(
        recommendation == "COMPRAR" ~ "🟢",
        recommendation == "MANTER" ~ "🟡",
        recommendation == "OBSERVAR" ~ "🟠",
        TRUE ~ "🔴"
      )
    ) %>%
    select(rank, icon, ticker, total_score, quality, income, valuation,
           risk, dy_12m, pvp, recommendation) %>%
    print(n = top_n)

  cat("\n")
}

#' Get score for single FII
#'
#' @param ticker FII ticker
#' @return Score row
#' @export
get_fii_score <- function(ticker) {
  scores <- load_scores_for_analysis()

  score <- scores %>%
    filter(ticker == !!ticker)

  if (nrow(score) == 0) {
    warning(glue("No score found for {ticker}"))
    return(NULL)
  }

  return(score)
}

#' Format single FII report
#'
#' @param ticker FII ticker
#' @export
print_fii_report <- function(ticker) {
  score <- get_fii_score(ticker)

  if (is.null(score)) {
    return(invisible(NULL))
  }

  # Icon for recommendation
  icon <- case_when(
    score$recommendation == "COMPRAR" ~ "🟢",
    score$recommendation == "MANTER" ~ "🟡",
    score$recommendation == "OBSERVAR" ~ "🟠",
    TRUE ~ "🔴"
  )

  report <- glue("
  {icon} {score$ticker} - Score Total: {score$total_score}/100

  📊 Breakdown por Bloco:
    • Qualidade:  {score$quality}/100
    • Renda:      {score$income}/100
    • Valuation:  {score$valuation}/100
    • Risco:      {score$risk}/100

  💰 Indicadores-Chave:
    • Preço atual: R$ {format(score$current_price, decimal.mark=',', nsmall=2)}
    • P/VP:        {format(score$pvp, decimal.mark=',', nsmall=2)}
    • DY 12M:      {format(score$dy_12m, decimal.mark=',', nsmall=1)}%

  ✅ Recomendação: {score$recommendation}

  📈 Tipo: {score$tipo_fii}
  🔍 Data Quality: {round(score$data_completeness * 100, 0)}%
  🕐 Calculated: {format(score$calculated_at, '%Y-%m-%d %H:%M')}
  ")

  cat(report)
  cat("\n")
}

# ============================================================================
# SEGMENT ANALYSIS
# ============================================================================

#' Analyze segment statistics
#'
#' @param tipo_fii FII type (partial match)
#' @return Summary statistics
#' @export
analyze_segment <- function(tipo_fii) {
  scores <- load_scores_for_analysis()

  segment_scores <- scores %>%
    filter(str_detect(tipo_fii, !!tipo_fii))

  if (nrow(segment_scores) == 0) {
    warning(glue("No FIIs found for segment: {tipo_fii}"))
    return(NULL)
  }

  summary <- list(
    segment = tipo_fii,
    n_fiis = nrow(segment_scores),
    mean_score = mean(segment_scores$total_score, na.rm = TRUE),
    median_score = median(segment_scores$total_score, na.rm = TRUE),
    sd_score = sd(segment_scores$total_score, na.rm = TRUE),
    mean_dy = mean(segment_scores$dy_12m, na.rm = TRUE),
    mean_pvp = mean(segment_scores$pvp, na.rm = TRUE),
    n_comprar = sum(segment_scores$recommendation == "COMPRAR", na.rm = TRUE),
    top_fiis = segment_scores %>%
      arrange(desc(total_score)) %>%
      head(5) %>%
      pull(ticker)
  )

  return(summary)
}

# ============================================================================
# PORTFOLIO ANALYSIS
# ============================================================================

#' Portfolio summary statistics
#'
#' @export
portfolio_summary <- function() {
  portfolio_scores <- get_portfolio_scores()

  summary <- list(
    n_fiis = nrow(portfolio_scores),
    total_invested = sum(portfolio_scores$invested),
    total_current_value = sum(portfolio_scores$current_value),
    total_unrealized_gain = sum(portfolio_scores$unrealized_gain),
    return_pct = sum(portfolio_scores$unrealized_gain) /
                 sum(portfolio_scores$invested) * 100,

    mean_score = mean(portfolio_scores$total_score, na.rm = TRUE),
    median_score = median(portfolio_scores$total_score, na.rm = TRUE),

    weighted_dy = weighted.mean(portfolio_scores$dy_12m,
                                 portfolio_scores$current_value,
                                 na.rm = TRUE),

    n_comprar = sum(portfolio_scores$recommendation == "COMPRAR"),
    n_manter = sum(portfolio_scores$recommendation == "MANTER"),
    n_observar = sum(portfolio_scores$recommendation == "OBSERVAR"),
    n_evitar = sum(portfolio_scores$recommendation == "EVITAR")
  )

  return(summary)
}

#' Print portfolio summary
#'
#' @export
print_portfolio_summary <- function() {
  summary <- portfolio_summary()

  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("                   PORTFOLIO SUMMARY\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  cat("💰 Financial:\n")
  cat(glue("   Total Invested:      R$ {format(summary$total_invested, big.mark='.', decimal.mark=',', nsmall=2)}"), "\n")
  cat(glue("   Current Value:       R$ {format(summary$total_current_value, big.mark='.', decimal.mark=',', nsmall=2)}"), "\n")
  cat(glue("   Unrealized Gain:     R$ {format(summary$total_unrealized_gain, big.mark='.', decimal.mark=',', nsmall=2)}"), "\n")
  cat(glue("   Return:              {format(summary$return_pct, decimal.mark=',', nsmall=1)}%"), "\n\n")

  cat("📊 Scores:\n")
  cat(glue("   Mean Score:          {round(summary$mean_score, 1)}"), "\n")
  cat(glue("   Median Score:        {round(summary$median_score, 1)}"), "\n")
  cat(glue("   Weighted DY:         {format(summary$weighted_dy, decimal.mark=',', nsmall=1)}%"), "\n\n")

  cat("📈 Recommendations:\n")
  cat(glue("   🟢 COMPRAR:   {summary$n_comprar} ({round(summary$n_comprar/summary$n_fiis*100, 0)}%)"), "\n")
  cat(glue("   🟡 MANTER:    {summary$n_manter} ({round(summary$n_manter/summary$n_fiis*100, 0)}%)"), "\n")
  cat(glue("   🟠 OBSERVAR:  {summary$n_observar} ({round(summary$n_observar/summary$n_fiis*100, 0)}%)"), "\n")
  cat(glue("   🔴 EVITAR:    {summary$n_evitar} ({round(summary$n_evitar/summary$n_fiis*100, 0)}%)"), "\n\n")

  cat("═══════════════════════════════════════════════════════════════\n\n")
}

# ============================================================================
# SCORE CHANGE TRACKING
# ============================================================================

#' Get FIIs with recent score changes
#'
#' @param min_change Minimum change to report (default: 5)
#' @export
get_score_changes <- function(min_change = 5) {
  changes <- detect_score_changes(min_change)

  if (nrow(changes) == 0) {
    message("No significant score changes detected")
    return(tibble())
  }

  return(changes)
}

#' Print score changes report
#'
#' @param min_change Minimum change threshold
#' @export
print_score_changes <- function(min_change = 5) {
  changes <- get_score_changes(min_change)

  if (nrow(changes) == 0) {
    return(invisible(NULL))
  }

  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("              SCORE CHANGES (>", min_change, "points)\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  changes %>%
    mutate(
      icon = if_else(change > 0, "📈", "📉"),
      change_str = glue("{round(change, 1)} ({round(change_pct, 0)}%)")
    ) %>%
    select(icon, ticker, previous_score, latest_score, change_str) %>%
    print(n = Inf)

  cat("\n")
}
