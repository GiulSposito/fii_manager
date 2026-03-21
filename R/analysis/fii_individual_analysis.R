#' FII Individual Deep Analysis
#'
#' Comprehensive analysis framework for individual FII evaluation.
#' Implements 7 analysis sections:
#' 1. Perfil do FII
#' 2. Análise de Qualidade
#' 3. Análise de Renda
#' 4. Análise de Valuation
#' 5. Análise de Risco
#' 6. Cenários e Projeções
#' 7. Pontos de Atenção / Alertas
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)
library(glue)

# Load dependencies
source("./R/transform/fii_data_sources.R", encoding = "UTF-8")
source("./R/transform/fii_indicators.R", encoding = "UTF-8")
source("./R/transform/fii_deep_indicators.R", encoding = "UTF-8")

# ============================================================================
# MAIN ANALYSIS FUNCTION
# ============================================================================

#' Analyze FII with deep indicators
#'
#' Comprehensive analysis of a single FII ticker including quality, income,
#' valuation, risk, scenarios, and alerts.
#'
#' @param ticker Character FII ticker code (e.g., "HGLG11")
#' @param cache Optional list with pre-loaded data (scores, cvm, quotations, income, fiis, scores_history)
#' @return List with 7 analysis sections
#' @export
#' @examples
#' analysis <- analyze_fii_deep("HGLG11")
#' print_fii_analysis(analysis)
analyze_fii_deep <- function(ticker, cache = NULL) {

  # Load cache if not provided
  if (is.null(cache)) {
    cache <- load_analysis_cache()
  }

  # Validate ticker exists
  if (!ticker %in% cache$scores$ticker) {
    stop(glue("Ticker {ticker} not found in scores. Run scoring pipeline first."))
  }

  # Get base score data for ticker
  score_data <- cache$scores %>%
    filter(ticker == !!ticker)

  # Get historical data
  history <- if (!is.null(cache$scores_history)) {
    cache$scores_history %>%
      filter(ticker == !!ticker) %>%
      arrange(desc(calculated_at))
  } else {
    tibble()
  }

  # Get CVM data
  cvm_data <- if (!is.null(cache$cvm_data)) {
    cache$cvm_data %>%
      filter(ticker == !!ticker) %>%
      arrange(desc(data_competencia))
  } else {
    tibble()
  }

  # Get quotations
  quotes <- cache$quotations %>%
    filter(ticker == !!ticker) %>%
    arrange(desc(date))

  # Get income history
  income_hist <- cache$income %>%
    filter(ticker == !!ticker) %>%
    arrange(desc(data_pagamento))

  # Build analysis sections
  analysis <- list(
    ticker = ticker,
    analysis_date = Sys.time(),

    # Section 1: Profile
    perfil = build_perfil_section(score_data, cvm_data, cache),

    # Section 2: Quality
    qualidade = build_qualidade_section(score_data, cvm_data, history, cache),

    # Section 3: Income
    renda = build_renda_section(score_data, income_hist, history, cache),

    # Section 4: Valuation
    valuation = build_valuation_section(score_data, quotes, history, cache),

    # Section 5: Risk
    risco = build_risco_section(score_data, quotes, history, cache),

    # Section 6: Scenarios
    cenarios = build_cenarios_section(score_data, income_hist, quotes, cache),

    # Section 7: Alerts
    alertas = build_alertas_section(score_data, cvm_data, history, cache)
  )

  return(analysis)
}

# ============================================================================
# SECTION BUILDERS
# ============================================================================

#' Build profile section
#' @keywords internal
build_perfil_section <- function(score_data, cvm_data, cache) {

  # Get FII info
  fii_info <- cache$fiis %>%
    filter(ticker == score_data$ticker)

  # Get latest CVM data
  latest_cvm <- if (nrow(cvm_data) > 0) {
    cvm_data %>% slice_head(n = 1)
  } else {
    NULL
  }

  list(
    ticker = score_data$ticker,
    nome = if (nrow(fii_info) > 0) fii_info$nome else NA_character_,
    tipo_fii = score_data$tipo_fii,
    segmento = score_data$tipo_fii,
    administrador = if (nrow(fii_info) > 0) fii_info$administrador else NA_character_,
    patrimonio_liquido = if (!is.null(latest_cvm) && !is.na(latest_cvm$patrimonio_liquido)) {
      latest_cvm$patrimonio_liquido
    } else if (nrow(fii_info) > 0) {
      fii_info$patrimonio
    } else {
      NA_real_
    },
    numero_cotistas = if (!is.null(latest_cvm) && !is.na(latest_cvm$numero_cotistas)) {
      latest_cvm$numero_cotistas
    } else if (nrow(fii_info) > 0) {
      fii_info$numero_cotista
    } else {
      NA_real_
    },
    data_constituicao = if (!is.null(latest_cvm)) latest_cvm$data_competencia else NA,
    participacao_ifix = if (nrow(fii_info) > 0) fii_info$participacao_ifix else FALSE,
    estrategia = if (str_detect(score_data$tipo_fii, "Logística|Galpões")) {
      "Renda via locação de galpões logísticos"
    } else if (str_detect(score_data$tipo_fii, "Papel|Títulos")) {
      "Renda via títulos e recebíveis imobiliários"
    } else if (str_detect(score_data$tipo_fii, "Lajes")) {
      "Renda via locação de lajes corporativas"
    } else if (str_detect(score_data$tipo_fii, "Shopping")) {
      "Renda via locação em shopping centers"
    } else {
      "Renda via locação de imóveis"
    }
  )
}

#' Build quality analysis section
#' @keywords internal
build_qualidade_section <- function(score_data, cvm_data, history, cache) {

  # Calculate quality components
  vacancia_atual <- NA_real_
  vacancia_media_12m <- NA_real_
  vacancia_tendencia <- "estável"

  # Get vacancy data from CVM if available
  if (nrow(cvm_data) >= 1) {
    if ("vacancia_fisica" %in% names(cvm_data)) {
      vacancia_atual <- cvm_data$vacancia_fisica[1]
    }

    if (nrow(cvm_data) >= 12 && "vacancia_fisica" %in% names(cvm_data)) {
      recent_vacancy <- cvm_data %>%
        head(12) %>%
        pull(vacancia_fisica) %>%
        na.omit()

      if (length(recent_vacancy) >= 3) {
        vacancia_media_12m <- mean(recent_vacancy)

        # Trend detection
        first_half <- mean(recent_vacancy[1:min(6, length(recent_vacancy))])
        second_half <- mean(recent_vacancy[max(1, length(recent_vacancy)-5):length(recent_vacancy)])

        if (first_half < second_half - 2) {
          vacancia_tendencia <- "crescente"
        } else if (first_half > second_half + 2) {
          vacancia_tendencia <- "decrescente"
        }
      }
    }
  }

  # Get segment vacancy for comparison
  segment_vacancy <- get_segment_statistic(
    score_data$ticker,
    "vacancia_fisica",
    cache$cvm_data,
    cache$fiis
  )

  # Shareholder concentration
  concentracao_cotistas <- calc_concentracao_cotistas(cvm_data)

  # Leverage
  alavancagem_atual <- calc_alavancagem(cvm_data)

  alavancagem_historico <- if (nrow(cvm_data) >= 12) {
    map_dbl(1:min(12, nrow(cvm_data)), function(i) {
      calc_alavancagem(cvm_data %>% slice(i:n()))
    })
  } else {
    numeric(0)
  }

  # Equity stability
  estabilidade_cv <- calc_estabilidade_patrimonio(cvm_data)

  # Rating interpretation
  rating <- case_when(
    is.na(estabilidade_cv) ~ "N/A",
    estabilidade_cv < 0.05 ~ "Excelente",
    estabilidade_cv < 0.15 ~ "Boa",
    estabilidade_cv < 0.30 ~ "Moderada",
    TRUE ~ "Instável"
  )

  # Build diagnostics
  diagnostico <- build_quality_diagnostic(
    score_data$quality,
    vacancia_atual,
    alavancagem_atual,
    concentracao_cotistas,
    estabilidade_cv
  )

  # Alerts
  alertas <- character(0)

  if (!is.na(vacancia_atual) && vacancia_atual > 20) {
    alertas <- c(alertas, glue("Vacância elevada: {round(vacancia_atual, 1)}%"))
  }

  if (!is.na(alavancagem_atual) && alavancagem_atual > 0.5) {
    alertas <- c(alertas, glue("Alavancagem alta: {round(alavancagem_atual * 100, 1)}%"))
  }

  if (!is.na(concentracao_cotistas) && concentracao_cotistas > 0.7) {
    alertas <- c(alertas, "Alta concentração de cotistas")
  }

  list(
    score_qualidade = round(score_data$quality, 1),
    componentes = list(
      vacancia = list(
        atual = vacancia_atual,
        media_12m = vacancia_media_12m,
        tendencia = vacancia_tendencia,
        vs_segmento = segment_vacancy$median
      ),
      concentracao = list(
        cotistas = concentracao_cotistas,
        numero_cotistas = score_data$perfil$numero_cotistas
      ),
      alavancagem = list(
        atual = alavancagem_atual,
        historico_12m = alavancagem_historico,
        limite_seguro = 0.3
      ),
      estabilidade = list(
        patrimonio_cv = estabilidade_cv,
        rating = rating
      )
    ),
    diagnostico = diagnostico,
    alertas = alertas
  )
}

#' Build income analysis section
#' @keywords internal
build_renda_section <- function(score_data, income_hist, history, cache) {

  # Current DY
  dy_12m <- score_data$dy_12m

  # Historical DY
  dy_historico_24m <- if (nrow(history) > 0) {
    history %>%
      filter(!is.na(dy_12m)) %>%
      head(24) %>%
      pull(dy_12m)
  } else {
    numeric(0)
  }

  # Stability (CV of DY)
  estabilidade_cv <- if (length(dy_historico_24m) >= 3) {
    sd(dy_historico_24m) / mean(dy_historico_24m)
  } else {
    NA_real_
  }

  estabilidade_rating <- case_when(
    is.na(estabilidade_cv) ~ "N/A",
    estabilidade_cv < 0.10 ~ "Excelente",
    estabilidade_cv < 0.20 ~ "Boa",
    estabilidade_cv < 0.35 ~ "Moderada",
    TRUE ~ "Instável"
  )

  # Growth rates
  cagr_1y <- calculate_cagr(dy_historico_24m, 12)
  cagr_3y <- calculate_cagr(dy_historico_24m, 24)

  # Sustainability (estimate payout from income data)
  avg_monthly_income <- if (nrow(income_hist) >= 12) {
    income_12m <- income_hist %>% head(12)
    mean(income_12m$valor_provento, na.rm = TRUE)
  } else {
    NA_real_
  }

  # Build projection scenarios
  projecao_12m <- build_income_projection(
    dy_12m,
    estabilidade_cv,
    cagr_1y,
    score_data$current_price
  )

  # Diagnostic
  diagnostico <- build_income_diagnostic(
    score_data$income,
    dy_12m,
    estabilidade_cv,
    cagr_1y
  )

  list(
    score_renda = round(score_data$income, 1),
    dy_12m = dy_12m,
    dy_historico_24m = dy_historico_24m,
    estabilidade = list(
      cv = estabilidade_cv,
      rating = estabilidade_rating
    ),
    crescimento = list(
      cagr_1y = cagr_1y,
      cagr_3y = cagr_3y
    ),
    sustentabilidade = list(
      rendimento_medio_mensal = avg_monthly_income,
      cobertura = NA_real_  # Requires FFO data
    ),
    projecao_12m = projecao_12m,
    diagnostico = diagnostico
  )
}

#' Build valuation analysis section
#' @keywords internal
build_valuation_section <- function(score_data, quotes, history, cache) {

  # Current P/VP
  pvp_atual <- score_data$pvp

  # Historical P/VP
  pvp_historico_12m <- if (nrow(history) >= 12) {
    history %>%
      head(12) %>%
      pull(pvp) %>%
      na.omit()
  } else {
    numeric(0)
  }

  # Segment median P/VP
  segment_pvp <- get_segment_statistic(
    score_data$ticker,
    "pvp",
    cache$scores,
    cache$fiis
  )

  desconto_pct <- if (!is.na(segment_pvp$median) && segment_pvp$median > 0) {
    ((pvp_atual - segment_pvp$median) / segment_pvp$median) * 100
  } else {
    NA_real_
  }

  # Yield spread vs CDI (approximate CDI at 11.75% as of Mar 2026)
  cdi_rate <- 11.75
  yield_spread <- score_data$dy_12m - cdi_rate

  # Fair value estimate (simple model based on DY and segment P/VP)
  fair_value <- if (!is.na(segment_pvp$median)) {
    # Target P/VP = segment median, adjusted by relative DY
    segment_dy <- get_segment_statistic(
      score_data$ticker,
      "dy_12m",
      cache$scores,
      cache$fiis
    )

    if (!is.na(segment_dy$median) && segment_dy$median > 0) {
      dy_factor <- score_data$dy_12m / segment_dy$median
      target_pvp <- segment_pvp$median * dy_factor

      # Estimate book value from current price
      book_value <- score_data$current_price / pvp_atual

      target_price <- book_value * target_pvp
      upside <- ((target_price - score_data$current_price) / score_data$current_price) * 100

      list(
        estimativa = target_price,
        upside_downside_pct = upside
      )
    } else {
      list(estimativa = NA_real_, upside_downside_pct = NA_real_)
    }
  } else {
    list(estimativa = NA_real_, upside_downside_pct = NA_real_)
  }

  # Diagnostic
  diagnostico <- build_valuation_diagnostic(
    score_data$valuation,
    pvp_atual,
    desconto_pct,
    yield_spread
  )

  list(
    score_valuation = round(score_data$valuation, 1),
    pvp = list(
      atual = pvp_atual,
      historico_12m = pvp_historico_12m,
      mediana_segmento = segment_pvp$median,
      desconto_pct = desconto_pct
    ),
    yield_spread = list(
      vs_cdi = yield_spread,
      vs_ntnb = NA_real_  # Requires IPCA + spread data
    ),
    cap_rate = list(
      se_tijolo = NA_real_  # Requires NOI data for brick funds
    ),
    fair_value = fair_value,
    diagnostico = diagnostico
  )
}

#' Build risk analysis section
#' @keywords internal
build_risco_section <- function(score_data, quotes, history, cache) {

  # Volatility (annualized from daily returns)
  volatility <- if (nrow(quotes) >= 252) {
    returns <- quotes %>%
      arrange(date) %>%
      mutate(return = (price / lag(price) - 1)) %>%
      filter(!is.na(return)) %>%
      pull(return)

    sd(returns) * sqrt(252) * 100  # Annualized %
  } else {
    NA_real_
  }

  # Segment volatility for comparison
  segment_vol <- get_segment_statistic(
    score_data$ticker,
    "volatility",
    cache$scores,
    cache$fiis
  )

  # Max drawdown (12 months)
  drawdown_data <- calculate_drawdown(quotes, months = 12)

  # Liquidity metrics
  liquidez <- if (nrow(quotes) >= 21) {
    recent_quotes <- quotes %>%
      head(21) %>%
      filter(!is.na(volume))

    list(
      volume_medio = mean(recent_quotes$volume * recent_quotes$price, na.rm = TRUE),
      dias_negociacao = nrow(recent_quotes),
      spread_bid_ask = NA_real_  # Requires bid/ask data
    )
  } else {
    list(
      volume_medio = NA_real_,
      dias_negociacao = NA_integer_,
      spread_bid_ask = NA_real_
    )
  }

  # Beta vs IFIX (requires IFIX data)
  beta <- NA_real_

  # Diagnostic
  diagnostico <- build_risk_diagnostic(
    score_data$risk,
    volatility,
    drawdown_data$max_drawdown,
    liquidez$volume_medio
  )

  list(
    score_risco = round(score_data$risk, 1),
    volatilidade = list(
      anual = volatility,
      vs_segmento = segment_vol$median,
      vs_ifix = NA_real_
    ),
    drawdown = list(
      maximo_12m = drawdown_data$max_drawdown,
      atual = drawdown_data$current_drawdown,
      recuperacao_dias = drawdown_data$recovery_days
    ),
    liquidez = liquidez,
    beta = list(
      vs_ifix = beta,
      interpretacao = "N/A"
    ),
    diagnostico = diagnostico
  )
}

#' Build scenarios section
#' @keywords internal
build_cenarios_section <- function(score_data, income_hist, quotes, cache) {

  # Base assumptions
  current_dy <- score_data$dy_12m
  current_pvp <- score_data$pvp
  current_price <- score_data$current_price

  # Optimistic scenario: +10% DY, +5% P/VP
  otimista <- list(
    dy_proj = current_dy * 1.10,
    pvp_proj = current_pvp * 1.05,
    retorno_esperado = (current_dy * 1.10) + 5  # DY + capital appreciation
  )

  # Base scenario: stable DY, stable P/VP
  base <- list(
    dy_proj = current_dy,
    pvp_proj = current_pvp,
    retorno_esperado = current_dy
  )

  # Pessimistic scenario: -10% DY, -5% P/VP
  pessimista <- list(
    dy_proj = current_dy * 0.90,
    pvp_proj = current_pvp * 0.95,
    retorno_esperado = (current_dy * 0.90) - 5
  )

  # Sensitivity analysis
  sensibilidade <- list(
    vacancia_plus5 = -0.5 * current_dy,  # 5% vacancy increase => -50% DY impact (estimate)
    vacancia_minus5 = 0.3 * current_dy,  # 5% vacancy decrease => +30% DY impact
    juros_plus1 = -3.0  # 1% Selic increase => -3% P/VP impact (rule of thumb)
  )

  list(
    cenario_otimista = otimista,
    cenario_base = base,
    cenario_pessimista = pessimista,
    sensibilidade = sensibilidade
  )
}

#' Build alerts section
#' @keywords internal
build_alertas_section <- function(score_data, cvm_data, history, cache) {

  criticos <- character(0)
  importantes <- character(0)
  informativos <- character(0)

  # Critical alerts
  if (!is.na(score_data$quality) && score_data$quality < 40) {
    criticos <- c(criticos, glue("Score de qualidade muito baixo: {round(score_data$quality, 1)}"))
  }

  if (nrow(cvm_data) >= 1 && "vacancia_fisica" %in% names(cvm_data)) {
    if (!is.na(cvm_data$vacancia_fisica[1]) && cvm_data$vacancia_fisica[1] > 20) {
      criticos <- c(criticos, glue("Vacância crítica: {round(cvm_data$vacancia_fisica[1], 1)}%"))
    }
  }

  alavancagem <- calc_alavancagem(cvm_data)
  if (!is.na(alavancagem) && alavancagem > 0.50) {
    criticos <- c(criticos, glue("Alavancagem elevada: {round(alavancagem * 100, 1)}%"))
  }

  # Important changes
  if (nrow(history) >= 2) {
    score_change <- score_data$total_score - history$total_score[2]
    if (abs(score_change) >= 10) {
      importantes <- c(importantes, glue("Mudança significativa no score: {round(score_change, 1)} pontos"))
    }

    dy_change <- score_data$dy_12m - history$dy_12m[2]
    if (abs(dy_change) >= 1) {
      importantes <- c(importantes, glue("Mudança no DY: {round(dy_change, 2)}pp"))
    }
  }

  # Informational
  if (!is.na(score_data$pvp) && score_data$pvp < 0.80) {
    informativos <- c(informativos, glue("Negociando com desconto: P/VP = {round(score_data$pvp, 2)}"))
  }

  if (!is.na(score_data$dy_12m) && score_data$dy_12m > 12) {
    informativos <- c(informativos, glue("DY acima de 12%: {round(score_data$dy_12m, 2)}%"))
  }

  # Recommendation
  recomendacao <- score_data$recommendation

  list(
    criticos = criticos,
    importantes = importantes,
    informativos = informativos,
    recomendacao = recomendacao
  )
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Get segment statistic for comparison
#' @keywords internal
get_segment_statistic <- function(ticker, indicator, data, fiis_info) {

  # Get ticker segment
  ticker_segment <- fiis_info %>%
    filter(ticker == !!ticker) %>%
    pull(tipo_fii) %>%
    first()

  if (is.na(ticker_segment)) {
    return(list(median = NA_real_, mean = NA_real_, n = 0))
  }

  # Get segment data
  segment_data <- if ("ticker" %in% names(data)) {
    segment_tickers <- fiis_info %>%
      filter(tipo_fii == ticker_segment) %>%
      pull(ticker)

    data %>%
      filter(ticker %in% segment_tickers)
  } else {
    data
  }

  # Extract indicator values
  if (indicator %in% names(segment_data)) {
    values <- segment_data %>%
      pull(!!indicator) %>%
      na.omit()

    if (length(values) >= 3) {
      return(list(
        median = median(values),
        mean = mean(values),
        n = length(values)
      ))
    }
  }

  return(list(median = NA_real_, mean = NA_real_, n = 0))
}

#' Calculate CAGR from time series
#' @keywords internal
calculate_cagr <- function(values, periods) {
  if (length(values) < periods) {
    return(NA_real_)
  }

  start_value <- values[periods]
  end_value <- values[1]

  if (is.na(start_value) || is.na(end_value) || start_value <= 0) {
    return(NA_real_)
  }

  cagr <- ((end_value / start_value) ^ (12 / periods) - 1) * 100
  return(cagr)
}

#' Calculate drawdown metrics
#' @keywords internal
calculate_drawdown <- function(quotes, months = 12) {

  cutoff_date <- today() - months(months)

  recent_quotes <- quotes %>%
    filter(date >= cutoff_date) %>%
    arrange(date)

  if (nrow(recent_quotes) < 2) {
    return(list(
      max_drawdown = NA_real_,
      current_drawdown = NA_real_,
      recovery_days = NA_integer_
    ))
  }

  # Calculate running maximum
  recent_quotes <- recent_quotes %>%
    mutate(
      running_max = cummax(price),
      drawdown = (price / running_max - 1) * 100
    )

  max_drawdown <- min(recent_quotes$drawdown, na.rm = TRUE)
  current_drawdown <- recent_quotes$drawdown[nrow(recent_quotes)]

  # Recovery days (if currently recovered)
  recovery_days <- if (current_drawdown >= -1) {
    max_dd_date <- recent_quotes %>%
      filter(drawdown == max_drawdown) %>%
      pull(date) %>%
      first()

    as.integer(today() - max_dd_date)
  } else {
    NA_integer_
  }

  list(
    max_drawdown = max_drawdown,
    current_drawdown = current_drawdown,
    recovery_days = recovery_days
  )
}

#' Build income projection
#' @keywords internal
build_income_projection <- function(current_dy, stability_cv, growth_cagr, current_price) {

  # Optimistic: continuation of growth + reduced volatility
  dy_otimista <- if (!is.na(growth_cagr) && growth_cagr > 0) {
    current_dy * (1 + growth_cagr / 100)
  } else {
    current_dy * 1.05
  }

  # Base: maintain current DY
  dy_base <- current_dy

  # Pessimistic: negative growth or increased volatility
  dy_pessimista <- if (!is.na(stability_cv) && stability_cv > 0.3) {
    current_dy * 0.90
  } else {
    current_dy * 0.95
  }

  list(
    otimista = dy_otimista,
    base = dy_base,
    pessimista = dy_pessimista
  )
}

#' Build diagnostic text for quality
#' @keywords internal
build_quality_diagnostic <- function(score, vacancia, alavancagem, concentracao, estabilidade_cv) {

  if (is.na(score)) {
    return("Dados insuficientes para análise de qualidade")
  }

  if (score >= 75) {
    return("FII apresenta excelente qualidade operacional com indicadores sólidos em todos os aspectos analisados.")
  } else if (score >= 60) {
    return("FII apresenta boa qualidade com alguns pontos de atenção. Fundamentos sólidos no geral.")
  } else if (score >= 40) {
    return("FII apresenta qualidade moderada. Requer monitoramento de indicadores operacionais.")
  } else {
    return("FII apresenta baixa qualidade operacional. Cautela recomendada.")
  }
}

#' Build diagnostic text for income
#' @keywords internal
build_income_diagnostic <- function(score, dy, stability_cv, growth) {

  if (is.na(score)) {
    return("Dados insuficientes para análise de renda")
  }

  stability_text <- if (!is.na(stability_cv)) {
    if (stability_cv < 0.15) "excelente" else if (stability_cv < 0.30) "boa" else "instável"
  } else {
    "não avaliada"
  }

  growth_text <- if (!is.na(growth)) {
    if (growth > 5) "crescimento" else if (growth < -5) "queda" else "estabilidade"
  } else {
    "tendência incerta"
  }

  glue("FII apresenta DY de {round(dy, 1)}% com estabilidade {stability_text} e {growth_text} dos proventos.")
}

#' Build diagnostic text for valuation
#' @keywords internal
build_valuation_diagnostic <- function(score, pvp, desconto_pct, yield_spread) {

  if (is.na(score)) {
    return("Dados insuficientes para análise de valuation")
  }

  valuation_level <- if (!is.na(pvp)) {
    if (pvp < 0.85) "desconto significativo"
    else if (pvp < 0.95) "leve desconto"
    else if (pvp < 1.05) "justo"
    else if (pvp < 1.15) "leve prêmio"
    else "prêmio significativo"
  } else {
    "não determinado"
  }

  yield_text <- if (!is.na(yield_spread)) {
    if (yield_spread > 3) "yield atrativo"
    else if (yield_spread > 0) "yield razoável"
    else "yield abaixo do CDI"
  } else {
    "yield não comparado"
  }

  glue("FII negocia com {valuation_level} (P/VP {round(pvp, 2)}) e {yield_text} vs CDI.")
}

#' Build diagnostic text for risk
#' @keywords internal
build_risk_diagnostic <- function(score, volatility, max_drawdown, volume) {

  if (is.na(score)) {
    return("Dados insuficientes para análise de risco")
  }

  vol_level <- if (!is.na(volatility)) {
    if (volatility < 10) "baixa"
    else if (volatility < 20) "moderada"
    else "alta"
  } else {
    "não avaliada"
  }

  liquidity_level <- if (!is.na(volume)) {
    if (volume > 1000000) "boa"
    else if (volume > 100000) "moderada"
    else "baixa"
  } else {
    "não avaliada"
  }

  glue("FII apresenta volatilidade {vol_level} e liquidez {liquidity_level}.")
}

#' Load all required cache data
#' @keywords internal
load_analysis_cache <- function() {

  cache <- list()

  # Load scores (required)
  if (!file.exists("data/fii_scores.rds")) {
    stop("Scores file not found. Run scoring pipeline first: source('R/transform/fii_score_pipeline.R'); run_scoring_pipeline()")
  }
  cache$scores <- readRDS("data/fii_scores.rds")

  # Load core data
  cache$quotations <- readRDS("data/quotations.rds")
  cache$income <- readRDS("data/income.rds")
  cache$fiis <- readRDS("data/fiis.rds")

  # Load CVM data if available
  if (file.exists("data/fii_cvm.rds")) {
    cache$cvm_data <- readRDS("data/fii_cvm.rds")
  } else {
    cache$cvm_data <- NULL
    message("CVM data not available. Some quality indicators will be NA.")
  }

  # Load scores history if available
  if (file.exists("data/fii_scores_history.rds")) {
    cache$scores_history <- readRDS("data/fii_scores_history.rds")
  } else {
    cache$scores_history <- NULL
    message("Scores history not available. Trend analysis will be limited.")
  }

  return(cache)
}

# ============================================================================
# COMPARISON HELPER
# ============================================================================

#' Compare with history to detect changes
#'
#' Detects significant changes in indicators vs historical values
#'
#' @param ticker Character ticker code
#' @param current Current analysis result
#' @param history Historical analysis results
#' @return List with detected changes
#' @export
compare_with_history <- function(ticker, current, history) {

  if (length(history) == 0) {
    return(list(changes_detected = FALSE, changes = list()))
  }

  changes <- list()

  # Compare total score
  if ("total_score" %in% names(current) && "total_score" %in% names(history[[1]])) {
    score_change <- current$total_score - history[[1]]$total_score
    if (abs(score_change) >= 5) {
      changes$score <- list(
        previous = history[[1]]$total_score,
        current = current$total_score,
        change = score_change,
        direction = if (score_change > 0) "improvement" else "decline"
      )
    }
  }

  # Compare DY
  if ("renda" %in% names(current) && "renda" %in% names(history[[1]])) {
    dy_change <- current$renda$dy_12m - history[[1]]$renda$dy_12m
    if (abs(dy_change) >= 0.5) {
      changes$dy <- list(
        previous = history[[1]]$renda$dy_12m,
        current = current$renda$dy_12m,
        change = dy_change
      )
    }
  }

  # Compare P/VP
  if ("valuation" %in% names(current) && "valuation" %in% names(history[[1]])) {
    pvp_change <- current$valuation$pvp$atual - history[[1]]$valuation$pvp$atual
    if (abs(pvp_change) >= 0.05) {
      changes$pvp <- list(
        previous = history[[1]]$valuation$pvp$atual,
        current = current$valuation$pvp$atual,
        change = pvp_change
      )
    }
  }

  list(
    changes_detected = length(changes) > 0,
    changes = changes
  )
}

# ============================================================================
# OUTPUT FORMATTING
# ============================================================================

#' Format analysis as markdown report
#'
#' Generates a markdown-formatted report from analysis result
#'
#' @param analysis Result from analyze_fii_deep()
#' @return Character string with markdown content
#' @export
format_fii_report_markdown <- function(analysis) {

  # Icon for recommendation
  icon <- case_when(
    analysis$alertas$recomendacao == "COMPRAR" ~ "🟢",
    analysis$alertas$recomendacao == "MANTER" ~ "🟡",
    analysis$alertas$recomendacao == "OBSERVAR" ~ "🟠",
    TRUE ~ "🔴"
  )

  markdown <- glue("
# {icon} Análise Profunda: {analysis$ticker}

**Data da Análise:** {format(analysis$analysis_date, '%Y-%m-%d %H:%M')}
**Recomendação:** {analysis$alertas$recomendacao}

---

## 1. Perfil do FII

- **Nome:** {analysis$perfil$nome}
- **Tipo:** {analysis$perfil$tipo_fii}
- **Segmento:** {analysis$perfil$segmento}
- **Administrador:** {analysis$perfil$administrador}
- **Patrimônio Líquido:** R$ {format(analysis$perfil$patrimonio_liquido, big.mark='.', decimal.mark=',', scientific=FALSE)}
- **Número de Cotistas:** {format(analysis$perfil$numero_cotistas, big.mark='.')}
- **Participa IFIX:** {if (analysis$perfil$participacao_ifix) 'Sim' else 'Não'}
- **Estratégia:** {analysis$perfil$estrategia}

---

## 2. Análise de Qualidade

**Score:** {analysis$qualidade$score_qualidade}/100

### Componentes

- **Vacância:**
  - Atual: {if (!is.na(analysis$qualidade$componentes$vacancia$atual)) paste0(round(analysis$qualidade$componentes$vacancia$atual, 1), '%') else 'N/A'}
  - Média 12M: {if (!is.na(analysis$qualidade$componentes$vacancia$media_12m)) paste0(round(analysis$qualidade$componentes$vacancia$media_12m, 1), '%') else 'N/A'}
  - Tendência: {analysis$qualidade$componentes$vacancia$tendencia}

- **Alavancagem:**
  - Atual: {if (!is.na(analysis$qualidade$componentes$alavancagem$atual)) paste0(round(analysis$qualidade$componentes$alavancagem$atual * 100, 1), '%') else 'N/A'}
  - Limite Seguro: {analysis$qualidade$componentes$alavancagem$limite_seguro * 100}%

- **Estabilidade Patrimonial:**
  - CV: {if (!is.na(analysis$qualidade$componentes$estabilidade$patrimonio_cv)) round(analysis$qualidade$componentes$estabilidade$patrimonio_cv, 3) else 'N/A'}
  - Rating: {analysis$qualidade$componentes$estabilidade$rating}

**Diagnóstico:** {analysis$qualidade$diagnostico}

{if (length(analysis$qualidade$alertas) > 0) paste0('**Alertas:** ', paste(analysis$qualidade$alertas, collapse = '; ')) else ''}

---

## 3. Análise de Renda

**Score:** {analysis$renda$score_renda}/100

- **DY 12M:** {round(analysis$renda$dy_12m, 2)}%
- **Estabilidade:** {analysis$renda$estabilidade$rating} (CV: {if (!is.na(analysis$renda$estabilidade$cv)) round(analysis$renda$estabilidade$cv, 3) else 'N/A'})
- **Crescimento:**
  - CAGR 1Y: {if (!is.na(analysis$renda$crescimento$cagr_1y)) paste0(round(analysis$renda$crescimento$cagr_1y, 1), '%') else 'N/A'}
  - CAGR 3Y: {if (!is.na(analysis$renda$crescimento$cagr_3y)) paste0(round(analysis$renda$crescimento$cagr_3y, 1), '%') else 'N/A'}

### Projeção 12M

- **Otimista:** {round(analysis$renda$projecao_12m$otimista, 2)}%
- **Base:** {round(analysis$renda$projecao_12m$base, 2)}%
- **Pessimista:** {round(analysis$renda$projecao_12m$pessimista, 2)}%

**Diagnóstico:** {analysis$renda$diagnostico}

---

## 4. Análise de Valuation

**Score:** {analysis$valuation$score_valuation}/100

- **P/VP Atual:** {round(analysis$valuation$pvp$atual, 2)}
- **Mediana do Segmento:** {if (!is.na(analysis$valuation$pvp$mediana_segmento)) round(analysis$valuation$pvp$mediana_segmento, 2) else 'N/A'}
- **Desconto/Prêmio:** {if (!is.na(analysis$valuation$pvp$desconto_pct)) paste0(round(analysis$valuation$pvp$desconto_pct, 1), '%') else 'N/A'}
- **Yield Spread vs CDI:** {if (!is.na(analysis$valuation$yield_spread$vs_cdi)) paste0(round(analysis$valuation$yield_spread$vs_cdi, 2), 'pp') else 'N/A'}

### Fair Value

- **Estimativa:** R$ {if (!is.na(analysis$valuation$fair_value$estimativa)) format(analysis$valuation$fair_value$estimativa, decimal.mark=',', nsmall=2) else 'N/A'}
- **Upside/Downside:** {if (!is.na(analysis$valuation$fair_value$upside_downside_pct)) paste0(round(analysis$valuation$fair_value$upside_downside_pct, 1), '%') else 'N/A'}

**Diagnóstico:** {analysis$valuation$diagnostico}

---

## 5. Análise de Risco

**Score:** {analysis$risco$score_risco}/100

- **Volatilidade Anual:** {if (!is.na(analysis$risco$volatilidade$anual)) paste0(round(analysis$risco$volatilidade$anual, 1), '%') else 'N/A'}
- **Max Drawdown 12M:** {if (!is.na(analysis$risco$drawdown$maximo_12m)) paste0(round(analysis$risco$drawdown$maximo_12m, 1), '%') else 'N/A'}
- **Drawdown Atual:** {if (!is.na(analysis$risco$drawdown$atual)) paste0(round(analysis$risco$drawdown$atual, 1), '%') else 'N/A'}
- **Liquidez (Volume Médio):** R$ {if (!is.na(analysis$risco$liquidez$volume_medio)) format(analysis$risco$liquidez$volume_medio, big.mark='.', decimal.mark=',', scientific=FALSE) else 'N/A'}

**Diagnóstico:** {analysis$risco$diagnostico}

---

## 6. Cenários e Projeções

### Retorno Esperado 12M

| Cenário | DY Projetado | P/VP Projetado | Retorno Total |
|---------|--------------|----------------|---------------|
| Otimista | {round(analysis$cenarios$cenario_otimista$dy_proj, 2)}% | {round(analysis$cenarios$cenario_otimista$pvp_proj, 2)} | {round(analysis$cenarios$cenario_otimista$retorno_esperado, 1)}% |
| Base | {round(analysis$cenarios$cenario_base$dy_proj, 2)}% | {round(analysis$cenarios$cenario_base$pvp_proj, 2)} | {round(analysis$cenarios$cenario_base$retorno_esperado, 1)}% |
| Pessimista | {round(analysis$cenarios$cenario_pessimista$dy_proj, 2)}% | {round(analysis$cenarios$cenario_pessimista$pvp_proj, 2)} | {round(analysis$cenarios$cenario_pessimista$retorno_esperado, 1)}% |

### Análise de Sensibilidade

- **Vacância +5pp:** Impacto DY {round(analysis$cenarios$sensibilidade$vacancia_plus5, 2)}pp
- **Vacância -5pp:** Impacto DY {round(analysis$cenarios$sensibilidade$vacancia_minus5, 2)}pp
- **Juros +1pp:** Impacto P/VP {round(analysis$cenarios$sensibilidade$juros_plus1, 1)}%

---

## 7. Pontos de Atenção e Alertas

### Críticos
{if (length(analysis$alertas$criticos) > 0) paste0('- ', paste(analysis$alertas$criticos, collapse = '\\n- ')) else 'Nenhum'}

### Importantes
{if (length(analysis$alertas$importantes) > 0) paste0('- ', paste(analysis$alertas$importantes, collapse = '\\n- ')) else 'Nenhum'}

### Informativos
{if (length(analysis$alertas$informativos) > 0) paste0('- ', paste(analysis$alertas$informativos, collapse = '\\n- ')) else 'Nenhum'}

---

## Recomendação Final: {icon} {analysis$alertas$recomendacao}

")

  return(markdown)
}

#' Print formatted analysis to console
#'
#' Prints a readable summary of the analysis to console
#'
#' @param analysis Result from analyze_fii_deep()
#' @export
print_fii_analysis <- function(analysis) {

  # Icon for recommendation
  icon <- case_when(
    analysis$alertas$recomendacao == "COMPRAR" ~ "🟢",
    analysis$alertas$recomendacao == "MANTER" ~ "🟡",
    analysis$alertas$recomendacao == "OBSERVAR" ~ "🟠",
    TRUE ~ "🔴"
  )

  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat(glue("           ANÁLISE PROFUNDA: {analysis$ticker}"), "\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  # Section 1: Profile
  cat("1. PERFIL DO FII\n")
  cat(glue("   Tipo: {analysis$perfil$tipo_fii}"), "\n")
  cat(glue("   Cotistas: {format(analysis$perfil$numero_cotistas, big.mark='.')}"), "\n")
  cat(glue("   PL: R$ {format(analysis$perfil$patrimonio_liquido, big.mark='.', decimal.mark=',', scientific=FALSE)}"), "\n\n")

  # Section 2: Quality
  cat("2. QUALIDADE\n")
  cat(glue("   Score: {analysis$qualidade$score_qualidade}/100"), "\n")
  cat(glue("   {analysis$qualidade$diagnostico}"), "\n")
  if (length(analysis$qualidade$alertas) > 0) {
    cat("   Alertas:", paste(analysis$qualidade$alertas, collapse = "; "), "\n")
  }
  cat("\n")

  # Section 3: Income
  cat("3. RENDA\n")
  cat(glue("   Score: {analysis$renda$score_renda}/100"), "\n")
  cat(glue("   DY 12M: {round(analysis$renda$dy_12m, 2)}%"), "\n")
  cat(glue("   {analysis$renda$diagnostico}"), "\n\n")

  # Section 4: Valuation
  cat("4. VALUATION\n")
  cat(glue("   Score: {analysis$valuation$score_valuation}/100"), "\n")
  cat(glue("   P/VP: {round(analysis$valuation$pvp$atual, 2)}"), "\n")
  cat(glue("   {analysis$valuation$diagnostico}"), "\n\n")

  # Section 5: Risk
  cat("5. RISCO\n")
  cat(glue("   Score: {analysis$risco$score_risco}/100"), "\n")
  cat(glue("   {analysis$risco$diagnostico}"), "\n\n")

  # Section 6: Scenarios
  cat("6. CENÁRIOS (Retorno 12M)\n")
  cat(glue("   Otimista:  {round(analysis$cenarios$cenario_otimista$retorno_esperado, 1)}%"), "\n")
  cat(glue("   Base:      {round(analysis$cenarios$cenario_base$retorno_esperado, 1)}%"), "\n")
  cat(glue("   Pessimista: {round(analysis$cenarios$cenario_pessimista$retorno_esperado, 1)}%"), "\n\n")

  # Section 7: Alerts
  cat("7. ALERTAS\n")
  if (length(analysis$alertas$criticos) > 0) {
    cat("   CRÍTICOS:\n")
    for (alert in analysis$alertas$criticos) {
      cat(glue("   - {alert}"), "\n")
    }
  }
  if (length(analysis$alertas$importantes) > 0) {
    cat("   IMPORTANTES:\n")
    for (alert in analysis$alertas$importantes) {
      cat(glue("   - {alert}"), "\n")
    }
  }
  cat("\n")

  # Final recommendation
  cat("═══════════════════════════════════════════════════════════════\n")
  cat(glue("   RECOMENDAÇÃO: {icon} {analysis$alertas$recomendacao}"), "\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
}
