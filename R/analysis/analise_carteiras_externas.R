# Análise Crítica das Carteiras Externas (Empiricus)
# Avalia diversificação, concentração, yields, e qualidade

library(tidyverse)
library(lubridate)

# Load utility functions
source("R/utils/ticker_utils.R")

# Load external portfolios
carteiras <- readRDS("data/carteiras_externas.rds")

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

#' Analyze portfolio concentration
#'
#' @param df Portfolio dataframe with Peso column
#' @return List with concentration metrics
analyzeConcentration <- function(df) {
  # Check if Peso column exists
  if (!"Peso" %in% names(df)) {
    # If no weights, assume equal weighting
    df$Peso <- 1 / nrow(df)
  }

  sorted_weights <- sort(df$Peso, decreasing = TRUE)

  list(
    n_assets = nrow(df),
    top3_concentration = sum(sorted_weights[1:min(3, length(sorted_weights))]),
    top5_concentration = sum(sorted_weights[1:min(5, length(sorted_weights))]),
    herfindahl = sum(sorted_weights^2),  # HHI index
    max_weight = max(sorted_weights),
    min_weight = min(sorted_weights),
    weight_cv = sd(sorted_weights) / mean(sorted_weights)  # Coefficient of variation
  )
}

#' Analyze segment diversification
#'
#' @param df Portfolio dataframe with Segmento column
#' @return Tibble with segment distribution
analyzeSegments <- function(df) {
  # Check if Peso column exists
  if (!"Peso" %in% names(df)) {
    df$Peso <- 1 / nrow(df)
  }

  df %>%
    group_by(Segmento) %>%
    summarise(
      n_assets = n(),
      total_weight = sum(Peso),
      .groups = "drop"
    ) %>%
    arrange(desc(total_weight))
}

#' Analyze yield distribution
#'
#' @param df Portfolio dataframe with Yield columns
#' @return List with yield statistics
analyzeYields <- function(df) {
  # Check if yield columns exist
  has_yields <- "Yield Anualizado" %in% names(df)

  if (!has_yields) {
    return(list(
      mean_yield_udm = NA,
      median_yield_udm = NA,
      sd_yield_udm = NA,
      mean_yield_anual = NA,
      median_yield_anual = NA,
      sd_yield_anual = NA,
      min_yield_anual = NA,
      max_yield_anual = NA
    ))
  }

  list(
    mean_yield_udm = mean(df$`Yield UDM`, na.rm = TRUE),
    median_yield_udm = median(df$`Yield UDM`, na.rm = TRUE),
    sd_yield_udm = sd(df$`Yield UDM`, na.rm = TRUE),
    mean_yield_anual = mean(df$`Yield Anualizado`, na.rm = TRUE),
    median_yield_anual = median(df$`Yield Anualizado`, na.rm = TRUE),
    sd_yield_anual = sd(df$`Yield Anualizado`, na.rm = TRUE),
    min_yield_anual = min(df$`Yield Anualizado`, na.rm = TRUE),
    max_yield_anual = max(df$`Yield Anualizado`, na.rm = TRUE)
  )
}

#' Get market data for tickers
#'
#' @param tickers Character vector of tickers
#' @return List with market data summaries
getMarketData <- function(tickers) {
  result <- list()

  if (!is.null(quotations)) {
    # Get latest prices from market data
    latest_quotes <- quotations %>%
      filter(ticker %in% tickers) %>%
      group_by(ticker) %>%
      slice_max(date, n = 1) %>%
      ungroup()

    result$quotes <- latest_quotes
  }

  if (!is.null(proventos)) {
    # Get recent dividends (last 12 months)
    one_year_ago <- today() - years(1)

    recent_prov <- proventos %>%
      filter(ticker %in% tickers, data_com >= one_year_ago) %>%
      group_by(ticker) %>%
      summarise(
        n_payments = n(),
        total_prov_12m = sum(valor, na.rm = TRUE),
        mean_prov = mean(valor, na.rm = TRUE),
        .groups = "drop"
      )

    result$dividends <- recent_prov
  }

  return(result)
}

#' Generate critical analysis report for a portfolio
#'
#' @param portfolio_df Portfolio dataframe
#' @param portfolio_name Name of the portfolio
#' @return Character vector with analysis text
analyzeCritically <- function(portfolio_df, portfolio_name) {

  cat("\n", strrep("=", 80), "\n")
  cat("ANÁLISE CRÍTICA:", toupper(portfolio_name), "\n")
  cat(strrep("=", 80), "\n\n")

  # Extract tickers
  portfolio_df <- portfolio_df %>%
    mutate(ticker = extractTicker(Nome))

  cat("📊 COMPOSIÇÃO GERAL\n")
  cat(sprintf("   Total de ativos: %d\n", nrow(portfolio_df)))

  # Only show peso total if Peso column exists
  if ("Peso" %in% names(portfolio_df)) {
    cat(sprintf("   Peso total: %.1f%%\n\n", sum(portfolio_df$Peso, na.rm = TRUE) * 100))
  } else {
    cat("   (Pesos não informados - assumindo pesos iguais)\n\n")
  }

  # Concentration analysis
  conc <- analyzeConcentration(portfolio_df)
  cat("🎯 ANÁLISE DE CONCENTRAÇÃO\n")
  cat(sprintf("   Top 3 ativos: %.1f%% (", conc$top3_concentration * 100))
  if (conc$top3_concentration > 0.5) {
    cat("⚠️  ALTA CONCENTRAÇÃO)\n")
  } else if (conc$top3_concentration > 0.35) {
    cat("⚡ MODERADA)\n")
  } else {
    cat("✅ BEM DIVERSIFICADO)\n")
  }

  cat(sprintf("   Top 5 ativos: %.1f%%\n", conc$top5_concentration * 100))
  cat(sprintf("   Índice Herfindahl: %.4f (", conc$herfindahl))
  if (conc$herfindahl > 0.15) {
    cat("concentrado)\n")
  } else if (conc$herfindahl > 0.10) {
    cat("moderado)\n")
  } else {
    cat("diversificado)\n")
  }
  cat(sprintf("   Maior peso: %.1f%% | Menor peso: %.1f%%\n",
              conc$max_weight * 100, conc$min_weight * 100))
  cat(sprintf("   Coef. Variação pesos: %.2f\n\n", conc$weight_cv))

  # Segment diversification
  segments <- analyzeSegments(portfolio_df)
  cat("🏢 DIVERSIFICAÇÃO POR SEGMENTO\n")
  for (i in 1:nrow(segments)) {
    cat(sprintf("   %-20s %2d ativos (%.1f%%)\n",
                segments$Segmento[i],
                segments$n_assets[i],
                segments$total_weight[i] * 100))
  }

  # Critical assessment of segment concentration
  cat("\n   Avaliação: ")
  n_segments <- nrow(segments)
  top_segment_weight <- segments$total_weight[1]

  if (n_segments < 3) {
    cat("⚠️  POUCA DIVERSIFICAÇÃO SETORIAL\n")
  } else if (top_segment_weight > 0.5) {
    cat("⚠️  FORTE CONCENTRAÇÃO EM", segments$Segmento[1], "\n")
  } else if (n_segments >= 5 && top_segment_weight < 0.35) {
    cat("✅ EXCELENTE DIVERSIFICAÇÃO SETORIAL\n")
  } else {
    cat("✅ BOA DIVERSIFICAÇÃO SETORIAL\n")
  }

  cat("\n")

  # Yield analysis
  yields <- analyzeYields(portfolio_df)
  cat("💰 ANÁLISE DE RENDIMENTO\n")

  if (is.na(yields$mean_yield_anual)) {
    cat("   Dados de yield não disponíveis para esta carteira\n")
    cat("   (FOFs e Hedge Funds tipicamente não divulgam yield direto)\n\n")
  } else {
    cat(sprintf("   Yield Anualizado Médio: %.2f%%\n", yields$mean_yield_anual))
    cat(sprintf("   Yield Anualizado Mediano: %.2f%%\n", yields$median_yield_anual))
    cat(sprintf("   Range: %.2f%% - %.2f%%\n", yields$min_yield_anual, yields$max_yield_anual))
    cat(sprintf("   Desvio Padrão: %.2f%%\n", yields$sd_yield_anual))

    cat("\n   Avaliação: ")
    if (yields$mean_yield_anual > 11) {
      cat("✅ YIELD ACIMA DA MÉDIA DO MERCADO\n")
    } else if (yields$mean_yield_anual > 9) {
      cat("✅ YIELD NA MÉDIA DO MERCADO\n")
    } else {
      cat("⚠️  YIELD ABAIXO DA MÉDIA DO MERCADO\n")
    }

    if (yields$sd_yield_anual > 2) {
      cat("   ⚠️  Alta dispersão de yields (maior risco/heterogeneidade)\n")
    }

    cat("\n")
  }

  # Gestora analysis
  cat("🏦 ANÁLISE DE GESTORAS\n")
  gestoras <- portfolio_df %>%
    count(Gestora, sort = TRUE) %>%
    mutate(pct = n / sum(n) * 100)

  for (i in 1:nrow(gestoras)) {
    cat(sprintf("   %-20s %2d FIIs (%.1f%%)\n",
                gestoras$Gestora[i],
                gestoras$n[i],
                gestoras$pct[i]))
  }

  cat("\n   Avaliação: ")
  if (nrow(gestoras) < 5) {
    cat("⚠️  CONCENTRAÇÃO EM POUCAS GESTORAS\n")
  } else {
    cat("✅ BOA DIVERSIFICAÇÃO DE GESTORAS\n")
  }

  cat("\n")

  # Top holdings analysis
  cat("🔝 TOP 5 POSIÇÕES\n")

  # Select columns based on what's available
  if ("Peso" %in% names(portfolio_df) && "Yield Anualizado" %in% names(portfolio_df)) {
    top5 <- portfolio_df %>%
      arrange(desc(Peso)) %>%
      head(5) %>%
      select(ticker, Nome, Segmento, Peso, `Yield Anualizado`, Gestora)

    for (i in 1:nrow(top5)) {
      cat(sprintf("   %d. %s (%.1f%%) - %s - Yield: %.2f%% - %s\n",
                  i,
                  top5$ticker[i],
                  top5$Peso[i] * 100,
                  top5$Segmento[i],
                  top5$`Yield Anualizado`[i],
                  top5$Gestora[i]))
    }
  } else {
    # FOF case - no weights or yields
    top5 <- portfolio_df %>%
      head(5) %>%
      select(ticker, Nome, Segmento, Gestora)

    for (i in 1:nrow(top5)) {
      cat(sprintf("   %d. %s - %s - %s\n",
                  i,
                  top5$ticker[i],
                  top5$Segmento[i],
                  top5$Gestora[i]))
    }
  }

  cat("\n")

  # Overall assessment
  cat("📋 AVALIAÇÃO GERAL\n")

  score <- 0
  max_score <- 5

  # Concentration score
  if (conc$top3_concentration <= 0.35) score <- score + 1

  # Segment diversity score
  if (n_segments >= 5 && top_segment_weight < 0.35) {
    score <- score + 1
  } else if (n_segments >= 3) {
    score <- score + 0.5
  }

  # Yield score (only if available)
  if (!is.na(yields$mean_yield_anual)) {
    if (yields$mean_yield_anual > 11) score <- score + 1
    if (yields$sd_yield_anual < 2) score <- score + 0.5
  }

  # Gestora diversity score
  if (nrow(gestoras) >= 5) score <- score + 1

  # Number of assets score
  if (nrow(portfolio_df) >= 15) score <- score + 0.5

  cat(sprintf("\n   ⭐ Score: %.1f / %.1f\n", score, max_score))

  if (score >= 4) {
    cat("   ✅ CARTEIRA EXCELENTE\n")
  } else if (score >= 3) {
    cat("   ✅ CARTEIRA BOA\n")
  } else if (score >= 2) {
    cat("   ⚡ CARTEIRA RAZOÁVEL\n")
  } else {
    cat("   ⚠️  CARTEIRA PRECISA DE MELHORIAS\n")
  }

  cat("\n")

  # Return analysis object
  invisible(list(
    concentration = conc,
    segments = segments,
    yields = yields,
    gestoras = gestoras,
    top5 = top5,
    score = score
  ))
}

# ===============================================================================
# MAIN ANALYSIS
# ===============================================================================

cat("\n")
cat(strrep("█", 80), "\n")
cat("    ANÁLISE CRÍTICA COMPLETA DAS CARTEIRAS EXTERNAS (EMPIRICUS)\n")
cat(strrep("█", 80), "\n")

# Analyze each portfolio
results <- list()

# 1. Carteira RENDA
results$renda <- analyzeCritically(carteiras$renda, "Carteira RENDA")

# 2. Carteira TÁTICA
results$tatica <- analyzeCritically(carteiras$tatica, "Carteira TÁTICA")

# 3. Carteira FOF
results$fof <- analyzeCritically(carteiras$fof, "Carteira FOF (Fundos de Fundos)")

# ===============================================================================
# COMPARATIVE ANALYSIS
# ===============================================================================

cat("\n", strrep("=", 80), "\n")
cat("ANÁLISE COMPARATIVA ENTRE AS CARTEIRAS\n")
cat(strrep("=", 80), "\n\n")

comparison <- tibble(
  Carteira = c("RENDA", "TÁTICA", "FOF"),
  N_Ativos = c(nrow(carteiras$renda), nrow(carteiras$tatica), nrow(carteiras$fof)),
  Yield_Medio = c(
    results$renda$yields$mean_yield_anual,
    results$tatica$yields$mean_yield_anual,
    NA  # FOF doesn't have yield data
  ),
  Top3_Conc = c(
    results$renda$concentration$top3_concentration,
    results$tatica$concentration$top3_concentration,
    results$fof$concentration$top3_concentration
  ),
  N_Segmentos = c(
    nrow(results$renda$segments),
    nrow(results$tatica$segments),
    nrow(results$fof$segments)
  ),
  N_Gestoras = c(
    nrow(results$renda$gestoras),
    nrow(results$tatica$gestoras),
    nrow(results$fof$gestoras)
  ),
  Score = c(
    results$renda$score,
    results$tatica$score,
    results$fof$score
  )
)

print(comparison)

cat("\n🏆 RANKING\n")
ranked <- comparison %>% arrange(desc(Score))
for (i in 1:nrow(ranked)) {
  cat(sprintf("   %d. %s (Score: %.1f)\n", i, ranked$Carteira[i], ranked$Score[i]))
}

cat("\n💡 RECOMENDAÇÕES FINAIS\n\n")

# Identify best and worst
best_cart <- ranked$Carteira[1]
worst_cart <- ranked$Carteira[nrow(ranked)]

cat(sprintf("   ✅ Melhor carteira: %s\n", best_cart))
cat(sprintf("   ⚠️  Carteira que precisa de mais atenção: %s\n\n", worst_cart))

# Specific recommendations
cat("   Recomendações específicas:\n\n")

if (results$renda$concentration$top3_concentration > 0.4) {
  cat("   • RENDA: Reduzir concentração nos top 3 ativos\n")
}

if (results$tatica$yields$mean_yield_anual < results$renda$yields$mean_yield_anual) {
  cat("   • TÁTICA: Como esperado, yield menor que RENDA (foco em ganho de capital)\n")
}

if (nrow(carteiras$fof) < 10) {
  cat("   • FOF: Considerar aumentar o número de FoFs para melhor diversificação\n")
}

cat("\n")

# Save results
saveRDS(results, "data/analise_carteiras_externas.rds")
cat("📁 Análise salva em: data/analise_carteiras_externas.rds\n\n")
