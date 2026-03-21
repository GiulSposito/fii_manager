#' FII Score - Multi-Factor Scoring System
#'
#' Implements the 4-block framework for FII evaluation:
#' - Block A: Quality (25%)
#' - Block B: Income (30%)
#' - Block C: Valuation (25%)
#' - Block D: Risk (20%)
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(lubridate)
library(glue)

source("./R/transform/fii_data_sources.R")
source("./R/transform/fii_indicators.R")

# ============================================================================
# BLOCK SCORING FUNCTIONS
# ============================================================================

#' Calculate Quality Block Score (Block A)
#'
#' @param indicators Tibble from calculate_all_indicators()
#' @param segment_stats Tibble with segment mean/sd for normalization
#' @return Numeric score (0-100)
calculate_quality_block <- function(indicators, segment_stats = NULL) {
  # Basic quality score from available data
  quality_raw <- indicators$quality_score_basic

  # Concentration score
  concentration <- indicators$concentration_score

  # Weighted average
  quality_score <- (quality_raw * 0.6) + (concentration * 0.4)

  return(quality_score)
}

#' Calculate Income Block Score (Block B)
#'
#' @param indicators Tibble from calculate_all_indicators()
#' @param segment_stats Tibble with segment mean/sd
#' @return Numeric score (0-100)
calculate_income_block <- function(indicators, segment_stats = NULL) {
  scores <- numeric(0)

  # DY 12M (40% weight) - higher is better
  if (!is.na(indicators$dy_12m)) {
    dy_score <- min((indicators$dy_12m / 12) * 100, 100) # Normalize: 12% DY = 100
    scores <- c(scores, dy_score * 0.4)
  }

  # Dividend stability (30% weight) - lower CV is better
  if (!is.na(indicators$dividend_stability)) {
    # CV < 0.1 = excellent, CV > 0.5 = poor
    stability_score <- max(0, min(100, (1 - indicators$dividend_stability / 0.5) * 100))
    scores <- c(scores, stability_score * 0.3)
  }

  # Dividend growth (30% weight) - positive growth is better
  if (!is.na(indicators$dividend_growth)) {
    # CAGR > 10% = excellent, CAGR < -5% = poor
    growth_score <- 50 + (indicators$dividend_growth * 3.33)
    growth_score <- max(0, min(100, growth_score))
    scores <- c(scores, growth_score * 0.3)
  }

  if (length(scores) == 0) {
    return(NA_real_)
  }

  income_score <- sum(scores) / (length(scores) / sum(c(0.4, 0.3, 0.3)))
  return(income_score)
}

#' Calculate Valuation Block Score (Block C)
#'
#' @param indicators Tibble from calculate_all_indicators()
#' @param segment_stats Tibble with segment mean/sd
#' @return Numeric score (0-100)
calculate_valuation_block <- function(indicators, segment_stats = NULL) {
  scores <- numeric(0)

  # P/VP (40% weight) - lower is better (discount)
  if (!is.na(indicators$pvp)) {
    # P/VP < 0.8 = excellent, P/VP > 1.2 = poor
    pvp_score <- 100 - ((indicators$pvp - 0.7) / 0.7) * 100
    pvp_score <- max(0, min(100, pvp_score))
    scores <- c(scores, pvp_score * 0.4)
  }

  # Discount/Premium (30% weight) - discount is better
  if (!is.na(indicators$discount_premium)) {
    # -20% discount = excellent, +20% premium = poor
    discount_score <- 50 - (indicators$discount_premium * 1.25)
    discount_score <- max(0, min(100, discount_score))
    scores <- c(scores, discount_score * 0.3)
  }

  # Yield spread (30% weight) - higher is better
  if (!is.na(indicators$yield_spread)) {
    # Spread > 4% = excellent, Spread < 0% = poor
    spread_score <- 50 + (indicators$yield_spread * 10)
    spread_score <- max(0, min(100, spread_score))
    scores <- c(scores, spread_score * 0.3)
  }

  if (length(scores) == 0) {
    return(NA_real_)
  }

  valuation_score <- sum(scores) / (length(scores) / sum(c(0.4, 0.3, 0.3)))
  return(valuation_score)
}

#' Calculate Risk Block Score (Block D)
#'
#' @param indicators Tibble from calculate_all_indicators()
#' @param segment_stats Tibble with segment mean/sd
#' @return Numeric score (0-100)
calculate_risk_block <- function(indicators, segment_stats = NULL) {
  scores <- numeric(0)

  # Liquidity (40% weight) - higher is better
  if (!is.na(indicators$liquidity_score)) {
    scores <- c(scores, indicators$liquidity_score * 0.4)
  }

  # Volatility (30% weight) - lower is better
  if (!is.na(indicators$volatility)) {
    # Volatility < 2% = excellent, Volatility > 10% = poor
    volatility_score <- max(0, min(100, (1 - indicators$volatility / 10) * 100))
    scores <- c(scores, volatility_score * 0.3)
  }

  # Max drawdown (30% weight) - smaller drawdown is better
  if (!is.na(indicators$max_drawdown)) {
    # Drawdown > -10% = excellent, Drawdown < -30% = poor
    drawdown_score <- max(0, min(100, (1 + indicators$max_drawdown / 30) * 100))
    scores <- c(scores, drawdown_score * 0.3)
  }

  if (length(scores) == 0) {
    return(NA_real_)
  }

  risk_score <- sum(scores) / (length(scores) / sum(c(0.4, 0.3, 0.3)))
  return(risk_score)
}

# ============================================================================
# MAIN SCORING FUNCTION
# ============================================================================

#' Calculate complete FII score
#'
#' @param ticker FII ticker code
#' @param include_statusinvest Fetch StatusInvest data (default: FALSE for speed)
#' @param cache Cached data or NULL
#' @param weights Named vector with block weights (default: A=25, B=30, C=25, D=20)
#' @return List with detailed score breakdown
#' @export
calculate_fii_score <- function(ticker,
                                 include_statusinvest = FALSE,
                                 cache = NULL,
                                 weights = c(quality = 0.25,
                                           income = 0.30,
                                           valuation = 0.25,
                                           risk = 0.20)) {

  # Validate weights sum to 1
  if (abs(sum(weights) - 1.0) > 0.01) {
    stop("Weights must sum to 1.0")
  }

  # Load cache if needed
  if (is.null(cache)) {
    cache <- load_cached_data()
  }

  # Get comprehensive data
  fii_data <- get_comprehensive_fii_data(
    ticker,
    include_statusinvest = include_statusinvest,
    cache = cache
  )

  # Validate data availability
  data_quality <- validate_fii_data(fii_data)

  if (!data_quality$has_price) {
    warning(glue("No price data available for {ticker}"))
    return(list(
      ticker = ticker,
      total_score = NA_real_,
      error = "No price data"
    ))
  }

  # Calculate all indicators
  indicators <- calculate_all_indicators(fii_data, cache)

  # Calculate block scores
  quality_score <- calculate_quality_block(indicators)
  income_score <- calculate_income_block(indicators)
  valuation_score <- calculate_valuation_block(indicators)
  risk_score <- calculate_risk_block(indicators)

  # Calculate total weighted score
  block_scores <- c(
    quality = quality_score,
    income = income_score,
    valuation = valuation_score,
    risk = risk_score
  )

  # Remove NA scores and adjust weights proportionally
  valid_blocks <- !is.na(block_scores)
  if (sum(valid_blocks) == 0) {
    total_score <- NA_real_
  } else {
    valid_weights <- weights[valid_blocks]
    valid_weights <- valid_weights / sum(valid_weights) # Renormalize
    total_score <- sum(block_scores[valid_blocks] * valid_weights)
  }

  # Determine recommendation
  recommendation <- case_when(
    is.na(total_score) ~ "INSUFFICIENT DATA",
    total_score >= 75 ~ "COMPRAR",
    total_score >= 60 ~ "MANTER",
    total_score >= 40 ~ "OBSERVAR",
    TRUE ~ "EVITAR"
  )

  # Compile result
  result <- list(
    ticker = ticker,
    tipo_fii = fii_data$base$tipo_fii,
    total_score = round(total_score, 1),

    # Block scores
    blocks = list(
      quality = round(quality_score, 1),
      income = round(income_score, 1),
      valuation = round(valuation_score, 1),
      risk = round(risk_score, 1)
    ),

    # Raw indicators
    indicators = indicators,

    # Metadata
    recommendation = recommendation,
    data_quality = data_quality,
    calculated_at = Sys.time(),

    # Price info
    current_price = fii_data$base$price,
    pvp = indicators$pvp,
    dy_12m = indicators$dy_12m
  )

  return(result)
}

#' Format score result as readable text
#'
#' @param score_result Result from calculate_fii_score()
#' @return Character string with formatted output
#' @export
format_score_report <- function(score_result) {
  if (is.na(score_result$total_score)) {
    return(glue("
    ❌ {score_result$ticker}: INSUFFICIENT DATA
    Error: {score_result$error}
    "))
  }

  # Icon for recommendation
  icon <- case_when(
    score_result$recommendation == "COMPRAR" ~ "🟢",
    score_result$recommendation == "MANTER" ~ "🟡",
    score_result$recommendation == "OBSERVAR" ~ "🟠",
    TRUE ~ "🔴"
  )

  report <- glue("
  {icon} {score_result$ticker} - Score Total: {score_result$total_score}/100

  📊 Breakdown por Bloco:
    • Qualidade:  {score_result$blocks$quality}/100
    • Renda:      {score_result$blocks$income}/100
    • Valuation:  {score_result$blocks$valuation}/100
    • Risco:      {score_result$blocks$risk}/100

  💰 Indicadores-Chave:
    • Preço atual: R$ {format(score_result$current_price, decimal.mark=',', nsmall=2)}
    • P/VP:        {format(score_result$pvp, decimal.mark=',', nsmall=2)}
    • DY 12M:      {format(score_result$dy_12m, decimal.mark=',', nsmall=1)}%

  ✅ Recomendação: {score_result$recommendation}

  📈 Tipo: {score_result$tipo_fii}
  🔍 Data Quality: {round(score_result$data_quality$data_completeness * 100, 0)}%
  ")

  return(report)
}

# ============================================================================
# BATCH SCORING
# ============================================================================

#' Calculate scores for multiple FIIs
#'
#' @param tickers Vector of ticker codes or "portfolio" for all portfolio FIIs
#' @param include_statusinvest Fetch StatusInvest data (slower)
#' @param parallel Use parallel processing (default: FALSE)
#' @return Tibble with scores for all tickers
#' @export
score_multiple_fiis <- function(tickers,
                                 include_statusinvest = FALSE,
                                 parallel = FALSE) {

  # Load cache once
  cache <- load_cached_data()

  # Handle "portfolio" shortcut
  if (length(tickers) == 1 && tickers == "portfolio") {
    tickers <- cache$portfolio %>%
      pull(ticker) %>%
      unique()
    message(glue("Scoring {length(tickers)} FIIs from portfolio..."))
  }

  # Progress bar
  pb <- txtProgressBar(min = 0, max = length(tickers), style = 3)

  # Calculate scores
  scores <- map_dfr(seq_along(tickers), function(i) {
    ticker <- tickers[i]
    setTxtProgressBar(pb, i)

    result <- tryCatch({
      score <- calculate_fii_score(
        ticker,
        include_statusinvest = include_statusinvest,
        cache = cache
      )

      tibble(
        ticker = score$ticker,
        tipo_fii = score$tipo_fii,
        total_score = score$total_score,
        quality = score$blocks$quality,
        income = score$blocks$income,
        valuation = score$blocks$valuation,
        risk = score$blocks$risk,
        recommendation = score$recommendation,
        current_price = score$current_price,
        pvp = score$pvp,
        dy_12m = score$dy_12m,
        data_completeness = score$data_quality$data_completeness
      )
    },
    error = function(e) {
      tibble(
        ticker = ticker,
        tipo_fii = NA_character_,
        total_score = NA_real_,
        quality = NA_real_,
        income = NA_real_,
        valuation = NA_real_,
        risk = NA_real_,
        recommendation = "ERROR",
        current_price = NA_real_,
        pvp = NA_real_,
        dy_12m = NA_real_,
        data_completeness = NA_real_
      )
    })

    return(result)
  })

  close(pb)

  # Sort by total score
  scores <- scores %>%
    arrange(desc(total_score))

  return(scores)
}

#' Print ranking table
#'
#' @param scores_df Result from score_multiple_fiis()
#' @param top_n Number of top FIIs to show (default: 10)
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
