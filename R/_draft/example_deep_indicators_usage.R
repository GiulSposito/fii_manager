# Example: Using Deep Indicators with Real Data
#
# This script demonstrates how to use fii_deep_indicators.R with actual
# portfolio data to enrich scoring with advanced indicators.

library(tidyverse)
library(lubridate)
library(glue)

source("R/transform/fii_deep_indicators.R")

# ============================================================================
# EXAMPLE 1: Calculate Deep Indicators for a Single FII
# ============================================================================

cat("\n=== EXAMPLE 1: Single FII Analysis ===\n\n")

# Load cache with all necessary data
cache <- load_deep_indicators_cache(
  cvm_file = "data/fii_cvm.rds",
  scores_file = "data/fii_scores.rds",
  fiis_file = "data/fiis.rds",
  history_file = NULL  # Optional: add path to scores history if available
)

# Calculate for a specific ticker (replace with actual ticker)
ticker <- "KNRI11"  # Example ticker

if (ticker %in% cache$fiis$ticker) {
  cat(glue("Calculating deep indicators for {ticker}...\n\n"))

  deep_ind <- calculate_all_deep_indicators(ticker, cache)

  cat("QUALITY INDICATORS:\n")
  cat(glue("  Alavancagem:              {round(deep_ind$alavancagem, 4)}\n"))
  cat(glue("  Concentração Cotistas:    {round(deep_ind$concentracao_cotistas, 4)}\n"))
  cat(glue("  Estabilidade Patrimônio:  {round(deep_ind$estabilidade_patrimonio, 4)}\n"))
  cat(glue("  Taxa Eficiência:          {round(deep_ind$taxa_eficiencia, 4)}%\n\n"))

  cat("TEMPORAL INDICATORS:\n")
  cat(glue("  Momentum 3M:              {round(deep_ind$momentum_3m, 2)}%\n"))
  cat(glue("  Momentum 6M:              {round(deep_ind$momentum_6m, 2)}%\n"))
  cat(glue("  Momentum 12M:             {round(deep_ind$momentum_12m, 2)}%\n"))
  cat(glue("  Trend DY:                 {round(deep_ind$trend_dy, 4)}\n"))
  cat(glue("  Volatilidade DY:          {round(deep_ind$vol_dy, 4)}\n"))
  cat(glue("  Vol Rentabilidade:        {round(deep_ind$vol_rentabilidade, 4)}\n\n"))

  cat("RELATIVE INDICATORS:\n")
  cat(glue("  Z-Score DY:               {round(deep_ind$zscore_dy, 2)}\n"))
  cat(glue("  Z-Score P/VP:             {round(deep_ind$zscore_pvp, 2)}\n"))
  cat(glue("  Percentil DY:             {round(deep_ind$percentile_dy, 1)}%\n"))
  cat(glue("  Percentil P/VP:           {round(deep_ind$percentile_pvp, 1)}%\n"))
  cat(glue("  Relative Strength 12M:    {round(deep_ind$relative_strength_12m, 2)}%\n\n"))
} else {
  cat(glue("Ticker {ticker} not found in cache\n"))
}

# ============================================================================
# EXAMPLE 2: Enrich All Scores with Deep Indicators
# ============================================================================

cat("\n=== EXAMPLE 2: Enrich All Portfolio Scores ===\n\n")

# Load existing basic scores
scores_file <- "data/fii_scores.rds"

if (file.exists(scores_file)) {
  basic_scores <- readRDS(scores_file)

  cat(glue("Loaded {nrow(basic_scores)} FII scores\n"))
  cat(glue("Current columns: {ncol(basic_scores)}\n\n"))

  # Enrich with deep indicators
  cat("Enriching scores with deep indicators...\n")
  enriched_scores <- enrich_scores_with_deep_indicators(basic_scores, cache)

  cat(glue("\nEnriched columns: {ncol(enriched_scores)}\n"))
  cat(glue("Added {ncol(enriched_scores) - ncol(basic_scores)} deep indicator columns\n\n"))

  # Save enriched scores
  output_file <- "data/fii_scores_enriched.rds"
  saveRDS(enriched_scores, output_file)
  cat(glue("Saved enriched scores to {output_file}\n\n"))

  # Show sample of enriched data
  cat("Sample of enriched scores (first 3 FIIs):\n")
  enriched_scores %>%
    select(ticker, total_score, alavancagem, momentum_3m, zscore_dy) %>%
    head(3) %>%
    print()

} else {
  cat(glue("Scores file not found: {scores_file}\n"))
  cat("Run scoring pipeline first to generate basic scores\n")
}

# ============================================================================
# EXAMPLE 3: Segment-Level Analysis
# ============================================================================

cat("\n\n=== EXAMPLE 3: Segment Analysis ===\n\n")

if (exists("enriched_scores") && !is.null(cache$fiis)) {

  # Join with segment info
  segment_analysis <- enriched_scores %>%
    left_join(
      cache$fiis %>% select(ticker, tipo_fii, segmento),
      by = "ticker"
    ) %>%
    group_by(tipo_fii) %>%
    summarise(
      n_fiis = n(),
      avg_alavancagem = mean(alavancagem, na.rm = TRUE),
      avg_concentracao = mean(concentracao_cotistas, na.rm = TRUE),
      avg_estabilidade = mean(estabilidade_patrimonio, na.rm = TRUE),
      avg_momentum_3m = mean(momentum_3m, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(n_fiis))

  cat("Average Deep Indicators by Segment:\n\n")
  print(segment_analysis, n = 20)

}

# ============================================================================
# EXAMPLE 4: Identify Best Opportunities Using Deep Indicators
# ============================================================================

cat("\n\n=== EXAMPLE 4: Top Opportunities (Deep Indicators) ===\n\n")

if (exists("enriched_scores")) {

  # Define criteria for opportunities
  opportunities <- enriched_scores %>%
    filter(
      # Quality: low leverage, low concentration
      alavancagem < 0.3 | is.na(alavancagem),
      concentracao_cotistas < 0.4 | is.na(concentracao_cotistas),

      # Temporal: positive momentum
      momentum_3m > 0 | is.na(momentum_3m),

      # Relative: above-average in segment
      zscore_dy > 0 | is.na(zscore_dy)
    ) %>%
    arrange(desc(total_score)) %>%
    select(
      ticker, total_score,
      alavancagem, concentracao_cotistas,
      momentum_3m, zscore_dy, percentile_dy
    )

  cat(glue("Found {nrow(opportunities)} opportunities matching criteria:\n"))
  cat("  - Low leverage (< 0.3)\n")
  cat("  - Low shareholder concentration (< 0.4)\n")
  cat("  - Positive momentum (3M)\n")
  cat("  - Above-average DY in segment (z-score > 0)\n\n")

  if (nrow(opportunities) > 0) {
    cat("Top 10 Opportunities:\n\n")
    opportunities %>%
      head(10) %>%
      print()
  }
}

# ============================================================================
# EXAMPLE 5: Compare Two FIIs Side-by-Side
# ============================================================================

cat("\n\n=== EXAMPLE 5: Side-by-Side Comparison ===\n\n")

if (exists("enriched_scores")) {

  # Pick two tickers to compare (replace with actual tickers)
  ticker_a <- enriched_scores$ticker[1]
  ticker_b <- enriched_scores$ticker[2]

  comparison <- enriched_scores %>%
    filter(ticker %in% c(ticker_a, ticker_b)) %>%
    select(
      ticker, total_score,
      alavancagem, concentracao_cotistas, estabilidade_patrimonio,
      momentum_3m, momentum_6m, trend_dy,
      zscore_dy, percentile_dy, relative_strength_12m
    ) %>%
    pivot_longer(
      cols = -ticker,
      names_to = "indicator",
      values_to = "value"
    ) %>%
    pivot_wider(
      names_from = ticker,
      values_from = value
    )

  cat(glue("Comparing {ticker_a} vs {ticker_b}:\n\n"))
  print(comparison, n = 50)
}

# ============================================================================
# EXAMPLE 6: Quality Score Dashboard
# ============================================================================

cat("\n\n=== EXAMPLE 6: Quality Dashboard ===\n\n")

if (exists("enriched_scores")) {

  # Create quality composite score
  quality_dashboard <- enriched_scores %>%
    mutate(
      # Normalize quality indicators to 0-100 scale
      qual_alavancagem = normalize_to_scale(
        1 - pmin(alavancagem, 1),  # Invert: lower is better
        0, 1, 100
      ),
      qual_concentracao = normalize_to_scale(
        1 - pmin(concentracao_cotistas, 1),
        0, 1, 100
      ),
      qual_estabilidade = normalize_to_scale(
        1 - pmin(estabilidade_patrimonio, 0.5),
        0, 1, 100
      ),

      # Composite quality score
      quality_composite = (
        coalesce(qual_alavancagem, 50) * 0.4 +
        coalesce(qual_concentracao, 50) * 0.3 +
        coalesce(qual_estabilidade, 50) * 0.3
      )
    ) %>%
    select(
      ticker, quality_composite,
      qual_alavancagem, qual_concentracao, qual_estabilidade,
      alavancagem, concentracao_cotistas, estabilidade_patrimonio
    ) %>%
    arrange(desc(quality_composite))

  cat("Top 10 FIIs by Quality Composite Score:\n\n")
  quality_dashboard %>%
    head(10) %>%
    select(ticker, quality_composite, alavancagem, concentracao_cotistas, estabilidade_patrimonio) %>%
    print()
}

cat("\n=== ALL EXAMPLES COMPLETED ===\n\n")
cat("Next steps:\n")
cat("  1. Review enriched_scores tibble\n")
cat("  2. Integrate deep indicators into scoring weights\n")
cat("  3. Build dashboards using enriched data\n")
cat("  4. Set up historical tracking for momentum/trend analysis\n\n")
