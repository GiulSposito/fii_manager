# Comparação: Portfolio Atual vs Carteiras Empiricus
# Análise crítica comparativa

library(tidyverse)
library(lubridate)

# Load utility functions
source("R/utils/ticker_utils.R")

# Load data
portfolio_transactions <- readRDS("data/portfolio.rds")
carteiras_empiricus <- readRDS("data/carteiras_externas.rds")
analise_empiricus <- readRDS("data/analise_carteiras_externas.rds")

# Load market data if available
proventos <- if (file.exists("data/fii_proventos.rds")) {
  readRDS("data/fii_proventos.rds")
} else {
  NULL
}

quotations <- if (file.exists("data/quotations.rds")) {
  readRDS("data/quotations.rds")
} else {
  NULL
}

#' Calculate current portfolio position from transactions
#'
#' @param transactions Dataframe with date, ticker, volume columns
#' @return Tibble with current positions
calculateCurrentPosition <- function(transactions) {
  transactions %>%
    group_by(ticker) %>%
    summarise(
      total_volume = sum(volume, na.rm = TRUE),
      avg_price = weighted.mean(price, volume, na.rm = TRUE),
      first_purchase = min(date, na.rm = TRUE),
      last_transaction = max(date, na.rm = TRUE),
      n_transactions = n(),
      .groups = "drop"
    ) %>%
    filter(total_volume > 0)  # Only current holdings
}

#' Add market data to portfolio
#'
#' @param portfolio Current portfolio positions
#' @return Portfolio with market prices and yields
enrichPortfolio <- function(portfolio) {

  # Add latest quotations
  if (!is.null(quotations)) {
    latest_quotes <- quotations %>%
      group_by(ticker) %>%
      slice_max(date, n = 1) %>%
      ungroup() %>%
      select(ticker, current_price = price, quote_date = date)

    portfolio <- portfolio %>%
      left_join(latest_quotes, by = "ticker")

    # Calculate market value and gains
    portfolio <- portfolio %>%
      mutate(
        invested_value = total_volume * avg_price,
        market_value = total_volume * coalesce(current_price, avg_price),
        gain_loss = market_value - invested_value,
        gain_loss_pct = (market_value / invested_value - 1) * 100
      )
  }

  # Add yield data from proventos (last 12 months)
  if (!is.null(proventos)) {
    one_year_ago <- today() - years(1)

    yield_12m <- proventos %>%
      filter(data_com >= one_year_ago) %>%
      group_by(ticker) %>%
      summarise(
        dividends_12m = sum(valor, na.rm = TRUE),
        n_payments = n(),
        .groups = "drop"
      )

    portfolio <- portfolio %>%
      left_join(yield_12m, by = "ticker")

    # Calculate yield
    portfolio <- portfolio %>%
      mutate(
        yield_12m = if_else(
          !is.na(current_price) & !is.na(dividends_12m),
          (dividends_12m / current_price) * 100,
          NA_real_
        )
      )
  }

  return(portfolio)
}

# Note: extractTicker() now sourced from R/utils/ticker_utils.R

#' Classify FII segment based on ticker or available data
#'
#' @param ticker FII ticker
#' @return Segment name (simplified)
classifySegment <- function(ticker) {
  # This is a simplified classifier - ideally load from external source
  # For now, return "Diversos"
  "Diversos"
}

# ===============================================================================
# MAIN ANALYSIS
# ===============================================================================

cat("\n")
cat(strrep("█", 80), "\n")
cat("    COMPARAÇÃO: PORTFOLIO ATUAL vs CARTEIRAS EMPIRICUS\n")
cat(strrep("█", 80), "\n\n")

# Calculate current portfolio position
cat("📊 Calculando posição atual do portfolio...\n")
current_portfolio <- calculateCurrentPosition(portfolio_transactions)

cat(sprintf("   Transações totais: %d\n", nrow(portfolio_transactions)))
cat(sprintf("   Ativos únicos negociados: %d\n",
            length(unique(portfolio_transactions$ticker))))
cat(sprintf("   Posições atuais (volume > 0): %d\n\n", nrow(current_portfolio)))

# Enrich with market data
current_portfolio <- enrichPortfolio(current_portfolio)

# Calculate total portfolio value
total_invested <- sum(current_portfolio$invested_value, na.rm = TRUE)
total_market <- sum(current_portfolio$market_value, na.rm = TRUE)
total_gain <- total_market - total_invested
total_gain_pct <- (total_market / total_invested - 1) * 100

cat("💰 VALOR DO PORTFOLIO\n")
cat(sprintf("   Valor investido: R$ %s\n", format(total_invested, big.mark = ".", decimal.mark = ",")))
cat(sprintf("   Valor de mercado: R$ %s\n", format(total_market, big.mark = ".", decimal.mark = ",")))
cat(sprintf("   Ganho/Perda: R$ %s (%.2f%%)\n\n",
            format(total_gain, big.mark = ".", decimal.mark = ","),
            total_gain_pct))

# Calculate portfolio weights
current_portfolio <- current_portfolio %>%
  mutate(
    weight = market_value / sum(market_value, na.rm = TRUE),
    weight_pct = weight * 100
  )

# Portfolio-level metrics
portfolio_metrics <- list(
  n_assets = nrow(current_portfolio),
  avg_yield = mean(current_portfolio$yield_12m, na.rm = TRUE),
  median_yield = median(current_portfolio$yield_12m, na.rm = TRUE),
  total_dividends = sum(current_portfolio$dividends_12m * current_portfolio$total_volume, na.rm = TRUE),
  portfolio_yield = if (total_market > 0) {
    sum(current_portfolio$dividends_12m * current_portfolio$total_volume, na.rm = TRUE) / total_market * 100
  } else {
    NA_real_
  }
)

# Concentration analysis
sorted_weights <- current_portfolio %>%
  arrange(desc(weight)) %>%
  pull(weight)

concentration <- list(
  top3_concentration = sum(sorted_weights[1:min(3, length(sorted_weights))]),
  top5_concentration = sum(sorted_weights[1:min(5, length(sorted_weights))]),
  top10_concentration = sum(sorted_weights[1:min(10, length(sorted_weights))]),
  herfindahl = sum(sorted_weights^2),
  max_weight = max(sorted_weights),
  min_weight = min(sorted_weights),
  weight_cv = sd(sorted_weights) / mean(sorted_weights)
)

# Display portfolio analysis
cat(strrep("=", 80), "\n")
cat("ANÁLISE DO PORTFOLIO ATUAL\n")
cat(strrep("=", 80), "\n\n")

cat("📊 COMPOSIÇÃO GERAL\n")
cat(sprintf("   Total de ativos: %d\n", portfolio_metrics$n_assets))
cat(sprintf("   Primeira compra: %s\n", min(current_portfolio$first_purchase)))
cat(sprintf("   Última transação: %s\n", max(current_portfolio$last_transaction)))
cat(sprintf("   Idade do portfolio: %.1f anos\n\n",
            as.numeric(today() - min(current_portfolio$first_purchase)) / 365.25))

cat("🎯 ANÁLISE DE CONCENTRAÇÃO\n")
cat(sprintf("   Top 3 ativos: %.1f%% (", concentration$top3_concentration * 100))
if (concentration$top3_concentration > 0.5) {
  cat("⚠️  ALTA CONCENTRAÇÃO)\n")
} else if (concentration$top3_concentration > 0.35) {
  cat("⚡ MODERADA)\n")
} else {
  cat("✅ BEM DIVERSIFICADO)\n")
}
cat(sprintf("   Top 5 ativos: %.1f%%\n", concentration$top5_concentration * 100))
cat(sprintf("   Top 10 ativos: %.1f%%\n", concentration$top10_concentration * 100))
cat(sprintf("   Índice Herfindahl: %.4f (", concentration$herfindahl))
if (concentration$herfindahl > 0.15) {
  cat("concentrado)\n")
} else if (concentration$herfindahl > 0.10) {
  cat("moderado)\n")
} else {
  cat("diversificado)\n")
}
cat(sprintf("   Maior peso: %.1f%% | Menor peso: %.2f%%\n\n",
            concentration$max_weight * 100, concentration$min_weight * 100))

cat("💰 ANÁLISE DE RENDIMENTO (últimos 12 meses)\n")
if (!is.na(portfolio_metrics$portfolio_yield)) {
  cat(sprintf("   Yield do Portfolio: %.2f%%\n", portfolio_metrics$portfolio_yield))
  cat(sprintf("   Yield Médio (ativos): %.2f%%\n", portfolio_metrics$avg_yield))
  cat(sprintf("   Yield Mediano: %.2f%%\n", portfolio_metrics$median_yield))
  cat(sprintf("   Dividendos recebidos (12m): R$ %s\n\n",
              format(portfolio_metrics$total_dividends, big.mark = ".", decimal.mark = ",")))
} else {
  cat("   Dados de yield não disponíveis\n\n")
}

cat("🔝 TOP 10 POSIÇÕES\n")
top10 <- current_portfolio %>%
  arrange(desc(weight)) %>%
  head(10) %>%
  select(ticker, total_volume, market_value, weight_pct, gain_loss_pct)

for (i in 1:nrow(top10)) {
  gain_str <- if (!is.na(top10$gain_loss_pct[i])) {
    sprintf("Ganho: %+.1f%%", top10$gain_loss_pct[i])
  } else {
    "Ganho: N/A"
  }

  cat(sprintf("   %2d. %s (%.1f%%) - R$ %s - %s\n",
              i,
              top10$ticker[i],
              top10$weight_pct[i],
              format(round(top10$market_value[i]), big.mark = ".", decimal.mark = ","),
              gain_str))
}

cat("\n")

# ===============================================================================
# COMPARATIVE ANALYSIS
# ===============================================================================

cat(strrep("=", 80), "\n")
cat("COMPARAÇÃO COM CARTEIRAS EMPIRICUS\n")
cat(strrep("=", 80), "\n\n")

# Create comparison table
comparison <- tibble(
  Carteira = c("SEU PORTFOLIO", "EMPIRICUS RENDA", "EMPIRICUS TÁTICA", "EMPIRICUS FOF"),
  N_Ativos = c(
    portfolio_metrics$n_assets,
    nrow(carteiras_empiricus$renda),
    nrow(carteiras_empiricus$tatica),
    nrow(carteiras_empiricus$fof)
  ),
  Yield = c(
    portfolio_metrics$portfolio_yield,
    analise_empiricus$renda$yields$mean_yield_anual,
    analise_empiricus$tatica$yields$mean_yield_anual,
    NA
  ),
  Top3_Conc = c(
    concentration$top3_concentration,
    analise_empiricus$renda$concentration$top3_concentration,
    analise_empiricus$tatica$concentration$top3_concentration,
    analise_empiricus$fof$concentration$top3_concentration
  ) * 100,
  HHI = c(
    concentration$herfindahl,
    analise_empiricus$renda$concentration$herfindahl,
    analise_empiricus$tatica$concentration$herfindahl,
    analise_empiricus$fof$concentration$herfindahl
  )
)

print(comparison, n = 4)

cat("\n")

# Detailed comparison
cat("📊 ANÁLISE COMPARATIVA DETALHADA\n\n")

# 1. Number of assets
cat("1️⃣ NÚMERO DE ATIVOS\n")
if (portfolio_metrics$n_assets >= 15) {
  cat("   ✅ Seu portfolio tem boa diversificação numérica\n")
} else if (portfolio_metrics$n_assets >= 10) {
  cat("   ⚡ Seu portfolio tem diversificação moderada\n")
} else {
  cat("   ⚠️  Seu portfolio tem poucos ativos\n")
}
cat(sprintf("   Você: %d | RENDA: %d | TÁTICA: %d | FOF: %d\n\n",
            portfolio_metrics$n_assets,
            nrow(carteiras_empiricus$renda),
            nrow(carteiras_empiricus$tatica),
            nrow(carteiras_empiricus$fof)))

# 2. Concentration
cat("2️⃣ CONCENTRAÇÃO (Top 3)\n")
sua_conc <- concentration$top3_concentration * 100
if (sua_conc <= 35) {
  cat("   ✅ Seu portfolio tem baixa concentração\n")
} else if (sua_conc <= 50) {
  cat("   ⚡ Seu portfolio tem concentração moderada\n")
} else {
  cat("   ⚠️  Seu portfolio tem alta concentração\n")
}
cat(sprintf("   Você: %.1f%% | RENDA: 44.5%% | TÁTICA: 45.0%% | FOF: 60.0%%\n\n", sua_conc))

# 3. Yield comparison
cat("3️⃣ YIELD (últimos 12 meses)\n")
if (!is.na(portfolio_metrics$portfolio_yield)) {
  seu_yield <- portfolio_metrics$portfolio_yield

  if (seu_yield > 11) {
    cat("   ✅ Seu portfolio tem yield acima da média\n")
  } else if (seu_yield > 9) {
    cat("   ✅ Seu portfolio tem yield na média\n")
  } else {
    cat("   ⚠️  Seu portfolio tem yield abaixo da média\n")
  }

  cat(sprintf("   Você: %.2f%% | RENDA: 9.92%% | TÁTICA: 10.91%%\n\n", seu_yield))

  # Yield comparison analysis
  if (seu_yield > analise_empiricus$renda$yields$mean_yield_anual &&
      seu_yield > analise_empiricus$tatica$yields$mean_yield_anual) {
    cat("   🏆 Seu portfolio SUPERA ambas carteiras Empiricus em yield!\n\n")
  } else if (seu_yield < analise_empiricus$renda$yields$mean_yield_anual &&
             seu_yield < analise_empiricus$tatica$yields$mean_yield_anual) {
    cat("   ⚠️  Ambas carteiras Empiricus têm yield superior ao seu\n\n")
  }
} else {
  cat("   ℹ️  Dados de yield não disponíveis para seu portfolio\n\n")
}

# 4. Diversification (HHI)
cat("4️⃣ ÍNDICE HERFINDAHL (menor = mais diversificado)\n")
if (concentration$herfindahl < 0.10) {
  cat("   ✅ Seu portfolio é bem diversificado\n")
} else if (concentration$herfindahl < 0.15) {
  cat("   ⚡ Seu portfolio tem diversificação moderada\n")
} else {
  cat("   ⚠️  Seu portfolio é concentrado\n")
}
cat(sprintf("   Você: %.4f | RENDA: 0.1131 | TÁTICA: 0.1212 | FOF: 0.2000\n\n",
            concentration$herfindahl))

# ===============================================================================
# OVERLAP ANALYSIS
# ===============================================================================

cat(strrep("=", 80), "\n")
cat("ANÁLISE DE SOBREPOSIÇÃO (OVERLAP)\n")
cat(strrep("=", 80), "\n\n")

# Extract tickers from Empiricus portfolios
empiricus_renda_tickers <- carteiras_empiricus$renda %>%
  mutate(ticker = extractTicker(Nome)) %>%
  pull(ticker)

empiricus_tatica_tickers <- carteiras_empiricus$tatica %>%
  mutate(ticker = extractTicker(Nome)) %>%
  pull(ticker)

empiricus_fof_tickers <- carteiras_empiricus$fof %>%
  mutate(ticker = extractTicker(Nome)) %>%
  pull(ticker)

# Calculate overlaps
overlap_renda <- intersect(current_portfolio$ticker, empiricus_renda_tickers)
overlap_tatica <- intersect(current_portfolio$ticker, empiricus_tatica_tickers)
overlap_fof <- intersect(current_portfolio$ticker, empiricus_fof_tickers)

cat("🔄 ATIVOS EM COMUM\n\n")

cat(sprintf("   Com RENDA: %d ativos (%.1f%% do seu portfolio)\n",
            length(overlap_renda),
            length(overlap_renda) / portfolio_metrics$n_assets * 100))
if (length(overlap_renda) > 0) {
  cat("      ", paste(overlap_renda, collapse = ", "), "\n")
}
cat("\n")

cat(sprintf("   Com TÁTICA: %d ativos (%.1f%% do seu portfolio)\n",
            length(overlap_tatica),
            length(overlap_tatica) / portfolio_metrics$n_assets * 100))
if (length(overlap_tatica) > 0) {
  cat("      ", paste(overlap_tatica, collapse = ", "), "\n")
}
cat("\n")

cat(sprintf("   Com FOF: %d ativos (%.1f%% do seu portfolio)\n",
            length(overlap_fof),
            length(overlap_fof) / portfolio_metrics$n_assets * 100))
if (length(overlap_fof) > 0) {
  cat("      ", paste(overlap_fof, collapse = ", "), "\n")
}
cat("\n")

# Union of all Empiricus recommendations
all_empiricus <- unique(c(empiricus_renda_tickers, empiricus_tatica_tickers, empiricus_fof_tickers))
total_overlap <- intersect(current_portfolio$ticker, all_empiricus)

cat(sprintf("   TOTAL (qualquer carteira): %d ativos (%.1f%%)\n",
            length(total_overlap),
            length(total_overlap) / portfolio_metrics$n_assets * 100))
if (length(total_overlap) > 0) {
  cat("      ", paste(total_overlap, collapse = ", "), "\n")
}
cat("\n")

# Assets you have that Empiricus doesn't recommend
not_in_empiricus <- setdiff(current_portfolio$ticker, all_empiricus)
cat(sprintf("   🎯 Ativos SEUS que não estão na Empiricus: %d (%.1f%%)\n",
            length(not_in_empiricus),
            length(not_in_empiricus) / portfolio_metrics$n_assets * 100))

# Assets Empiricus recommends that you don't have
not_in_your_portfolio <- setdiff(all_empiricus, current_portfolio$ticker)
cat(sprintf("   💡 Ativos da Empiricus que você NÃO tem: %d\n",
            length(not_in_your_portfolio)))
if (length(not_in_your_portfolio) > 0 && length(not_in_your_portfolio) <= 15) {
  cat("      ", paste(not_in_your_portfolio, collapse = ", "), "\n")
}

cat("\n")

# ===============================================================================
# FINAL SCORE & RECOMMENDATIONS
# ===============================================================================

cat(strrep("=", 80), "\n")
cat("AVALIAÇÃO FINAL & RECOMENDAÇÕES\n")
cat(strrep("=", 80), "\n\n")

# Calculate score for your portfolio
score <- 0
max_score <- 5

# Concentration score
if (concentration$top3_concentration <= 0.35) score <- score + 1
# Number of assets
if (portfolio_metrics$n_assets >= 15) score <- score + 0.5
# Yield score (if available)
if (!is.na(portfolio_metrics$portfolio_yield)) {
  if (portfolio_metrics$portfolio_yield > 11) score <- score + 1
  if (portfolio_metrics$portfolio_yield > 9) score <- score + 0.5
}
# Diversification (HHI)
if (concentration$herfindahl < 0.10) score <- score + 1

cat(sprintf("⭐ SCORE DO SEU PORTFOLIO: %.1f / %.1f\n\n", score, max_score))

if (score >= 4) {
  cat("   ✅ PORTFOLIO EXCELENTE\n\n")
} else if (score >= 3) {
  cat("   ✅ PORTFOLIO BOM\n\n")
} else if (score >= 2) {
  cat("   ⚡ PORTFOLIO RAZOÁVEL\n\n")
} else {
  cat("   ⚠️  PORTFOLIO PRECISA DE MELHORIAS\n\n")
}

cat("📋 RECOMENDAÇÕES PERSONALIZADAS\n\n")

# Specific recommendations based on analysis
rec_count <- 1

if (concentration$top3_concentration > 0.40) {
  cat(sprintf("   %d. REDUZIR CONCENTRAÇÃO\n", rec_count))
  top3_fiis <- current_portfolio %>%
    arrange(desc(weight)) %>%
    head(3) %>%
    pull(ticker)
  cat(sprintf("      Seus top 3 (%.1f%%): %s\n",
              concentration$top3_concentration * 100,
              paste(top3_fiis, collapse = ", ")))
  cat("      Sugestão: Rebalancear para ~30-35%\n\n")
  rec_count <- rec_count + 1
}

if (portfolio_metrics$n_assets < 12) {
  cat(sprintf("   %d. AUMENTAR DIVERSIFICAÇÃO\n", rec_count))
  cat(sprintf("      Você tem %d ativos, ideal: 12-20\n", portfolio_metrics$n_assets))
  cat("      Considere adicionar da lista Empiricus que você não tem\n\n")
  rec_count <- rec_count + 1
}

if (!is.na(portfolio_metrics$portfolio_yield) && portfolio_metrics$portfolio_yield < 9.5) {
  cat(sprintf("   %d. MELHORAR YIELD\n", rec_count))
  cat(sprintf("      Seu yield: %.2f%% (abaixo da média ~10%%)\n",
              portfolio_metrics$portfolio_yield))
  cat("      Considere FIIs de papel com yield > 11%\n\n")
  rec_count <- rec_count + 1
}

if (length(not_in_your_portfolio) > 0) {
  cat(sprintf("   %d. CONSIDERAR ADICIONAR\n", rec_count))
  cat("      FIIs recomendados pela Empiricus que você não tem:\n")

  # Show top recommendations from TÁTICA (best portfolio)
  top_empiricus_not_in <- carteiras_empiricus$tatica %>%
    mutate(ticker = extractTicker(Nome)) %>%
    filter(ticker %in% not_in_your_portfolio) %>%
    arrange(desc(Peso)) %>%
    head(5)

  if (nrow(top_empiricus_not_in) > 0) {
    for (i in 1:nrow(top_empiricus_not_in)) {
      cat(sprintf("      • %s (TÁTICA: %.1f%% | Yield: %.2f%%)\n",
                  extractTicker(top_empiricus_not_in$Nome[i]),
                  top_empiricus_not_in$Peso[i] * 100,
                  top_empiricus_not_in$`Yield Anualizado`[i]))
    }
  }
  cat("\n")
  rec_count <- rec_count + 1
}

cat("💡 CONCLUSÃO\n\n")

if (score > 2.5) {
  cat("   Seu portfolio está bem estruturado e competitivo com as\n")
  cat("   carteiras da Empiricus. Continue monitorando e rebalanceando.\n\n")
} else {
  cat("   Há oportunidades de melhoria. Considere as recomendações\n")
  cat("   acima para otimizar diversificação e retorno.\n\n")
}

# Save comparison results
results <- list(
  portfolio_metrics = portfolio_metrics,
  concentration = concentration,
  current_portfolio = current_portfolio,
  comparison = comparison,
  overlap_renda = overlap_renda,
  overlap_tatica = overlap_tatica,
  overlap_fof = overlap_fof,
  score = score
)

saveRDS(results, "data/comparacao_portfolio_empiricus.rds")
cat("📁 Análise salva em: data/comparacao_portfolio_empiricus.rds\n\n")
