# Test Deep Indicators Implementation
# Quick validation script for fii_deep_indicators.R

library(tidyverse)
library(lubridate)

source("R/transform/fii_deep_indicators.R")

# ============================================================================
# TEST 1: QUALITY INDICATORS
# ============================================================================

cat("\n=== TEST 1: QUALITY INDICATORS ===\n")

# Mock CVM data for testing
mock_cvm <- tibble(
  ticker = rep("TEST11", 12),
  data_competencia = seq(today() - months(11), today(), by = "1 month"),
  nome_fundo = "Test FII",
  segmento = "Logística",
  patrimonio_liquido = rnorm(12, mean = 1e9, sd = 5e7),
  valor_patrimonial_cota = rnorm(12, mean = 100, sd = 2),
  dividend_yield = rnorm(12, mean = 0.8, sd = 0.1),
  rentabilidade_mensal = rnorm(12, mean = 0.7, sd = 0.3),
  numero_cotistas = rep(15000, 12),
  tx_administracao = rep(0.8, 12)
)

cat("\nTesting calc_alavancagem()...\n")
alavancagem <- calc_alavancagem(mock_cvm)
cat(glue::glue("  Alavancagem (proxy): {round(alavancagem, 4)}\n"))

cat("\nTesting calc_concentracao_cotistas()...\n")
concentracao <- calc_concentracao_cotistas(mock_cvm)
cat(glue::glue("  Concentração: {round(concentracao, 4)} (15000 cotistas)\n"))

cat("\nTesting calc_estabilidade_patrimonio()...\n")
estabilidade <- calc_estabilidade_patrimonio(mock_cvm)
cat(glue::glue("  Estabilidade (CV): {round(estabilidade, 4)}\n"))

cat("\nTesting calc_taxa_eficiencia()...\n")
eficiencia <- calc_taxa_eficiencia(mock_cvm)
cat(glue::glue("  Taxa eficiência: {round(eficiencia, 4)}%\n"))

# ============================================================================
# TEST 2: TEMPORAL INDICATORS
# ============================================================================

cat("\n=== TEST 2: TEMPORAL INDICATORS ===\n")

# Mock indicator history with upward trend
mock_history <- tibble(
  date = seq(today() - months(18), today(), by = "1 month"),
  indicator_value = 8 + 0.1 * seq_along(date) + rnorm(length(date), 0, 0.3)
)

cat("\nTesting calc_momentum()...\n")
momentum <- calc_momentum(mock_history, windows = c(3, 6, 12))
cat(glue::glue("  Momentum 3M:  {round(momentum$momentum_3m, 2)}%\n"))
cat(glue::glue("  Momentum 6M:  {round(momentum$momentum_6m, 2)}%\n"))
cat(glue::glue("  Momentum 12M: {round(momentum$momentum_12m, 2)}%\n"))

cat("\nTesting calc_trend_score()...\n")
trend <- calc_trend_score(mock_history)
cat(glue::glue("  Trend (slope): {round(trend, 4)}\n"))

cat("\nTesting calc_volatility_indicators()...\n")
mock_vol_data <- tibble(
  dy = rnorm(12, mean = 8.5, sd = 0.8),
  rentabilidade = rnorm(12, mean = 0.7, sd = 0.3)
)
volatility <- calc_volatility_indicators(mock_vol_data, c("dy", "rentabilidade"))
cat(glue::glue("  Vol DY: {round(volatility$vol_dy, 4)}\n"))
cat(glue::glue("  Vol Rentabilidade: {round(volatility$vol_rentabilidade, 4)}\n"))

# ============================================================================
# TEST 3: RELATIVE INDICATORS
# ============================================================================

cat("\n=== TEST 3: RELATIVE INDICATORS ===\n")

# Mock segment data
segment_dy <- rnorm(20, mean = 8.0, sd = 1.5)
ticker_dy <- 9.2

cat("\nTesting calc_zscore_segment()...\n")
zscore <- calc_zscore_segment(ticker_dy, segment_dy)
cat(glue::glue("  Z-score DY: {round(zscore, 2)} (ticker: {ticker_dy}, segment mean: {round(mean(segment_dy), 2)})\n"))

cat("\nTesting calc_percentile_rank()...\n")
percentile <- calc_percentile_rank(ticker_dy, segment_dy)
cat(glue::glue("  Percentile DY: {round(percentile, 1)}%\n"))

cat("\nTesting calc_relative_strength()...\n")
mock_all_data <- tibble(
  ticker = rep(c("TICKER1", "TICKER2", "TICKER3", "TARGET"), each = 12),
  date = rep(seq(today() - months(11), today(), by = "1 month"), 4),
  indicator_value = c(
    seq(100, 105, length.out = 12) + rnorm(12, 0, 1),  # TICKER1: slight up
    seq(100, 95, length.out = 12) + rnorm(12, 0, 1),   # TICKER2: slight down
    rep(100, 12) + rnorm(12, 0, 1),                      # TICKER3: flat
    seq(100, 110, length.out = 12) + rnorm(12, 0, 1)    # TARGET: strong up
  )
)
rel_strength <- calc_relative_strength("TARGET", mock_all_data, window = 12)
cat(glue::glue("  Relative Strength: {round(rel_strength, 2)}% (vs segment avg)\n"))

# ============================================================================
# TEST 4: HELPER FUNCTIONS
# ============================================================================

cat("\n=== TEST 4: HELPER FUNCTIONS ===\n")

cat("\nTesting get_segment_peers()...\n")
mock_fiis <- tibble(
  ticker = c("LOG1", "LOG2", "LOG3", "TIJOLO1", "TIJOLO2"),
  tipo_fii = c("Logística", "Logística", "Logística", "Tijolo", "Tijolo")
)
peers <- get_segment_peers("LOG1", mock_fiis)
cat(glue::glue("  Peers of LOG1: {paste(peers, collapse=', ')}\n"))

cat("\nTesting calculate_segment_statistics()...\n")
mock_segment <- tibble(
  dy_12m = rnorm(15, mean = 8.5, sd = 1.2)
)
stats <- calculate_segment_statistics(mock_segment, "dy_12m")
cat(glue::glue("  Mean: {round(stats$mean, 2)}, SD: {round(stats$sd, 2)}, Median: {round(stats$median, 2)}\n"))
cat(glue::glue("  Q25: {round(stats$q25, 2)}, Q75: {round(stats$q75, 2)}, N: {stats$n}\n"))

cat("\nTesting normalize_to_scale()...\n")
normalized <- normalize_to_scale(7.5, min_val = 5, max_val = 10, scale = 100)
cat(glue::glue("  Normalize 7.5 in [5,10] to [0,100]: {round(normalized, 2)}\n"))

# ============================================================================
# TEST 5: CONSOLIDATION
# ============================================================================

cat("\n=== TEST 5: CONSOLIDATION (calculate_all_deep_indicators) ===\n")

# Build minimal cache
mock_cache <- list(
  cvm_data = mock_cvm,
  fiis = mock_fiis %>% add_row(ticker = "TEST11", tipo_fii = "Logística"),
  scores = tibble(
    ticker = c("TEST11", "LOG1", "LOG2"),
    dy_12m = c(9.2, 8.5, 8.0),
    pvp = c(0.95, 1.0, 1.05)
  ),
  scores_history = tibble(
    ticker = rep("TEST11", 12),
    calculated_at = seq(today() - months(11), today(), by = "1 month"),
    dy_12m = 8 + 0.1 * seq_len(12) + rnorm(12, 0, 0.2),
    total_score = rnorm(12, mean = 70, sd = 5)
  )
)

cat("\nCalculating all deep indicators for TEST11...\n")
deep_indicators <- calculate_all_deep_indicators("TEST11", mock_cache)

cat("\nDeep indicators calculated:\n")
print(as.list(deep_indicators), width = 100)

cat("\n=== TEST 6: ENRICHMENT ===\n")

mock_basic_scores <- tibble(
  ticker = c("TEST11", "LOG1"),
  total_score = c(75, 68),
  dy_12m = c(9.2, 8.5),
  pvp = c(0.95, 1.0)
)

cat("\nEnriching basic scores with deep indicators...\n")
enriched <- enrich_scores_with_deep_indicators(mock_basic_scores, mock_cache)

cat(glue::glue("\nOriginal columns: {ncol(mock_basic_scores)}\n"))
cat(glue::glue("Enriched columns: {ncol(enriched)}\n"))
cat(glue::glue("Added: {ncol(enriched) - ncol(mock_basic_scores)} deep indicator columns\n"))

cat("\nEnriched columns:\n")
cat(paste(names(enriched), collapse = ", "))
cat("\n")

cat("\n=== ALL TESTS COMPLETED ===\n\n")
