#' FII Opportunities - Intelligent Opportunity Detection
#'
#' Advanced opportunity detection system with:
#' - Multi-criteria screener with flexible operators
#' - Pattern detection (mean reversion, breakouts, momentum, value traps)
#' - Automated portfolio alerts
#' - Contextual recommendations based on user profile
#' - Comprehensive opportunity reporting
#'
#' Requires PRE-CALCULATED scores from fii_scores.rds and enriched
#' indicators from fii_deep_indicators.R
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)
library(glue)

# Load dependencies
if (file.exists("./R/analysis/fii_analysis.R")) {
  source("./R/analysis/fii_analysis.R", encoding = "UTF-8")
}

if (file.exists("./R/transform/fii_deep_indicators.R")) {
  source("./R/transform/fii_deep_indicators.R", encoding = "UTF-8")
}

# ============================================================================
# 1. ADVANCED SCREENER
# ============================================================================

#' Advanced FII opportunity screener
#'
#' Flexible multi-criteria screener with customizable filters and ranking.
#'
#' @param scores_enriched Tibble with scores + deep indicators
#' @param criteria Named list with min/max thresholds per indicator.
#'   Each element should be list(min=x, max=y). Either can be NULL.
#'   Example: list(total_score = list(min = 70), dy_12m = list(min = 0.08, max = 0.15))
#' @param operator "AND" (all criteria must match) or "OR" (any criterion matches)
#' @param blacklist Character vector of tickers to exclude
#' @param ranking_weights Named numeric vector of weights for custom scoring.
#'   If NULL, uses total_score for ranking. Example: c(quality = 0.3, income = 0.4, valuation = 0.3)
#' @return Tibble with filtered and ranked opportunities
#' @export
#'
#' @examples
#' \dontrun{
#' criteria <- list(
#'   total_score = list(min = 70),
#'   dy_12m = list(min = 0.08, max = 0.15),
#'   pvp = list(max = 1.0),
#'   vacancia = list(max = 0.10),
#'   momentum_3m = list(min = 0)
#' )
#'
#' opps <- find_opportunities_advanced(
#'   scores_enriched,
#'   criteria = criteria,
#'   operator = "AND",
#'   blacklist = c("XPML11", "HGLG11"),
#'   ranking_weights = c(quality = 0.25, income = 0.35, valuation = 0.25, risk = 0.15)
#' )
#' }
find_opportunities_advanced <- function(scores_enriched,
                                        criteria = list(),
                                        operator = "AND",
                                        blacklist = character(0),
                                        ranking_weights = NULL) {

  # Validate operator
  operator <- toupper(operator)
  if (!operator %in% c("AND", "OR")) {
    stop("operator must be 'AND' or 'OR'")
  }

  # Remove blacklist
  data <- scores_enriched %>%
    filter(!ticker %in% blacklist)

  if (nrow(data) == 0) {
    warning("No data after blacklist filter")
    return(tibble())
  }

  # Apply criteria filters
  if (length(criteria) > 0) {
    data <- filter_by_criteria(data, criteria, operator)
  }

  if (nrow(data) == 0) {
    message("No opportunities match the specified criteria")
    return(tibble())
  }

  # Calculate custom score if weights provided
  if (!is.null(ranking_weights)) {
    data <- data %>%
      mutate(custom_score = calculate_custom_score(., ranking_weights))
    ranking_col <- "custom_score"
  } else {
    ranking_col <- "total_score"
  }

  # Rank opportunities
  opportunities <- data %>%
    arrange(desc(!!sym(ranking_col))) %>%
    mutate(
      rank = row_number(),
      screening_date = Sys.time()
    )

  message(glue("Found {nrow(opportunities)} opportunities"))

  return(opportunities)
}

#' Filter data by multiple criteria with AND/OR logic
#'
#' @param data Tibble to filter
#' @param criteria Named list with min/max thresholds
#' @param operator "AND" or "OR"
#' @return Filtered tibble
#' @keywords internal
filter_by_criteria <- function(data, criteria, operator = "AND") {

  # Build filter expressions for each criterion
  filter_results <- map(names(criteria), function(indicator) {
    if (!indicator %in% names(data)) {
      warning(glue("Indicator '{indicator}' not found in data, skipping"))
      return(rep(TRUE, nrow(data)))
    }

    values <- data[[indicator]]
    threshold <- criteria[[indicator]]

    # Apply min/max filters
    passes_min <- if (!is.null(threshold$min)) {
      !is.na(values) & values >= threshold$min
    } else {
      rep(TRUE, length(values))
    }

    passes_max <- if (!is.null(threshold$max)) {
      !is.na(values) & values <= threshold$max
    } else {
      rep(TRUE, length(values))
    }

    passes_min & passes_max
  })

  # Combine with operator
  if (operator == "AND") {
    final_filter <- reduce(filter_results, `&`)
  } else {
    final_filter <- reduce(filter_results, `|`)
  }

  data[final_filter, ]
}

#' Calculate custom score with user-defined weights
#'
#' @param fii_data Tibble with score components
#' @param weights Named numeric vector of weights (must sum to 1.0)
#' @return Numeric vector of custom scores
#' @keywords internal
calculate_custom_score <- function(fii_data, weights) {

  # Normalize weights
  if (abs(sum(weights) - 1.0) > 0.01) {
    weights <- weights / sum(weights)
    message("Note: Weights normalized to sum to 1.0")
  }

  # Check all components exist
  missing <- setdiff(names(weights), names(fii_data))
  if (length(missing) > 0) {
    stop(glue("Missing score components: {paste(missing, collapse=', ')}"))
  }

  # Calculate weighted score
  custom_score <- map_dbl(seq_len(nrow(fii_data)), function(i) {
    sum(map_dbl(names(weights), function(component) {
      value <- fii_data[[component]][i]
      if (is.na(value)) return(0)
      value * weights[component]
    }))
  })

  return(custom_score)
}

# ============================================================================
# 2. PATTERN DETECTION
# ============================================================================

#' Detect mean reversion opportunities
#'
#' Identifies FIIs trading below historical P/VP average (temporary discount).
#'
#' @param scores_enriched Tibble with current scores
#' @param scores_history Tibble with historical scores (from fii_scores_history.rds)
#' @param window Number of months for historical average (default: 12)
#' @param min_discount_pct Minimum discount percentage to flag (default: 10)
#' @return Tibble with mean reversion opportunities
#' @export
detect_mean_reversion <- function(scores_enriched,
                                   scores_history = NULL,
                                   window = 12,
                                   min_discount_pct = 10) {

  # Load history if not provided
  if (is.null(scores_history)) {
    history_file <- "data/fii_scores_history.rds"
    if (!file.exists(history_file)) {
      warning("No scores history available for mean reversion detection")
      return(tibble())
    }
    scores_history <- readRDS(history_file)
  }

  if (nrow(scores_history) == 0) {
    warning("Empty scores history")
    return(tibble())
  }

  # Calculate historical P/VP average per ticker
  cutoff_date <- today() - months(window)

  pvp_stats <- scores_history %>%
    filter(calculated_at >= cutoff_date) %>%
    group_by(ticker) %>%
    summarise(
      pvp_mean = mean(pvp, na.rm = TRUE),
      pvp_sd = sd(pvp, na.rm = TRUE),
      pvp_median = median(pvp, na.rm = TRUE),
      n_observations = n(),
      .groups = "drop"
    ) %>%
    filter(n_observations >= 5)  # Require at least 5 historical points

  if (nrow(pvp_stats) == 0) {
    message("Insufficient historical data for mean reversion analysis")
    return(tibble())
  }

  # Compare current P/VP to historical average
  mean_reversion_opps <- scores_enriched %>%
    select(ticker, pvp, total_score, dy_12m, tipo_fii, recommendation) %>%
    inner_join(pvp_stats, by = "ticker") %>%
    mutate(
      desconto_pct = ((pvp_mean - pvp) / pvp_mean) * 100,
      dias_abaixo = NA_integer_,  # Would need daily data to calculate
      z_score_pvp = if_else(pvp_sd > 0, (pvp - pvp_mean) / pvp_sd, 0)
    ) %>%
    filter(
      desconto_pct >= min_discount_pct,
      pvp < pvp_mean,
      !is.na(pvp)
    ) %>%
    arrange(desc(desconto_pct))

  if (nrow(mean_reversion_opps) > 0) {
    message(glue("Found {nrow(mean_reversion_opps)} mean reversion opportunities"))
  } else {
    message("No mean reversion opportunities detected")
  }

  return(mean_reversion_opps)
}

#' Detect P/VP breakouts
#'
#' Identifies FIIs that broke through P/VP resistance levels.
#'
#' @param scores_enriched Tibble with current scores
#' @param scores_history Tibble with historical scores
#' @param threshold Percentile threshold for resistance (default: 0.85 = 85th percentile)
#' @param lookback_months Months to look back for resistance level (default: 12)
#' @return Tibble with breakout opportunities
#' @export
detect_breakouts <- function(scores_enriched,
                              scores_history = NULL,
                              threshold = 0.85,
                              lookback_months = 12) {

  # Load history if not provided
  if (is.null(scores_history)) {
    history_file <- "data/fii_scores_history.rds"
    if (!file.exists(history_file)) {
      warning("No scores history available for breakout detection")
      return(tibble())
    }
    scores_history <- readRDS(history_file)
  }

  if (nrow(scores_history) == 0) {
    warning("Empty scores history")
    return(tibble())
  }

  cutoff_date <- today() - months(lookback_months)

  # Calculate resistance levels (85th percentile of historical P/VP)
  resistance_levels <- scores_history %>%
    filter(calculated_at >= cutoff_date) %>%
    group_by(ticker) %>%
    summarise(
      resistance_pvp = quantile(pvp, threshold, na.rm = TRUE),
      max_pvp = max(pvp, na.rm = TRUE),
      n_obs = n(),
      .groups = "drop"
    ) %>%
    filter(n_obs >= 5)

  if (nrow(resistance_levels) == 0) {
    message("Insufficient historical data for breakout analysis")
    return(tibble())
  }

  # Get previous P/VP (from most recent history point)
  previous_pvp <- scores_history %>%
    arrange(ticker, desc(calculated_at)) %>%
    group_by(ticker) %>%
    slice_head(n = 2) %>%
    summarise(
      pvp_anterior = if_else(n() >= 2, nth(pvp, 2), NA_real_),
      .groups = "drop"
    )

  # Detect breakouts: current P/VP > resistance AND previous was below
  breakouts <- scores_enriched %>%
    select(ticker, pvp, total_score, dy_12m, tipo_fii, recommendation) %>%
    inner_join(resistance_levels, by = "ticker") %>%
    inner_join(previous_pvp, by = "ticker") %>%
    filter(
      !is.na(pvp),
      !is.na(pvp_anterior),
      pvp > resistance_pvp,
      pvp_anterior <= resistance_pvp
    ) %>%
    mutate(
      breakout_pct = ((pvp - resistance_pvp) / resistance_pvp) * 100,
      change_from_previous_pct = ((pvp - pvp_anterior) / pvp_anterior) * 100
    ) %>%
    arrange(desc(breakout_pct))

  if (nrow(breakouts) > 0) {
    message(glue("Found {nrow(breakouts)} breakout opportunities"))
  } else {
    message("No breakout patterns detected")
  }

  return(breakouts)
}

#' Detect positive momentum patterns
#'
#' Identifies FIIs with sustained positive momentum across multiple timeframes.
#'
#' @param scores_enriched Tibble with momentum indicators (momentum_3m, momentum_6m)
#' @param windows Vector of momentum windows to check (default: c(3, 6))
#' @param min_momentum Minimum momentum percentage for each window (default: 0)
#' @return Tibble with momentum opportunities
#' @export
detect_momentum_positivo <- function(scores_enriched,
                                     windows = c(3, 6),
                                     min_momentum = 0) {

  # Check for momentum columns
  momentum_cols <- paste0("momentum_", windows, "m")
  missing_cols <- setdiff(momentum_cols, names(scores_enriched))

  if (length(missing_cols) > 0) {
    warning(glue("Missing momentum indicators: {paste(missing_cols, collapse=', ')}"))
    return(tibble())
  }

  # Build filter for all momentum windows
  momentum_opps <- scores_enriched %>%
    select(ticker, total_score, dy_12m, pvp, tipo_fii, recommendation,
           all_of(momentum_cols))

  # Filter: all momentum indicators must be positive
  for (col in momentum_cols) {
    momentum_opps <- momentum_opps %>%
      filter(!is.na(!!sym(col)), !!sym(col) >= min_momentum)
  }

  if (nrow(momentum_opps) == 0) {
    message("No positive momentum opportunities detected")
    return(tibble())
  }

  # Calculate momentum acceleration (difference between windows)
  if (length(windows) >= 2) {
    col1 <- paste0("momentum_", windows[1], "m")
    col2 <- paste0("momentum_", windows[2], "m")

    momentum_opps <- momentum_opps %>%
      mutate(
        aceleracao = !!sym(col1) - !!sym(col2)
      )
  } else {
    momentum_opps <- momentum_opps %>%
      mutate(aceleracao = NA_real_)
  }

  momentum_opps <- momentum_opps %>%
    arrange(desc(momentum_3m))

  message(glue("Found {nrow(momentum_opps)} positive momentum opportunities"))

  return(momentum_opps)
}

#' Detect value traps
#'
#' Identifies FIIs with low P/VP but poor quality scores (value traps to avoid).
#'
#' @param scores_enriched Tibble with scores + deep indicators
#' @param pvp_threshold Maximum P/VP to be considered "cheap" (default: 0.90)
#' @param quality_threshold Maximum quality score for "poor quality" (default: 50)
#' @return Tibble with potential value traps
#' @export
detect_value_traps <- function(scores_enriched,
                                pvp_threshold = 0.90,
                                quality_threshold = 50) {

  # Identify: low P/VP but low quality score
  value_traps <- scores_enriched %>%
    filter(
      !is.na(pvp),
      !is.na(quality),
      pvp <= pvp_threshold,
      quality <= quality_threshold
    ) %>%
    select(ticker, pvp, quality, total_score, dy_12m, tipo_fii, recommendation)

  if (nrow(value_traps) == 0) {
    message("No value traps detected")
    return(tibble())
  }

  # Add reasons to avoid
  value_traps <- value_traps %>%
    mutate(
      razao_evitar = case_when(
        quality <= 30 ~ "Qualidade muito baixa",
        quality <= 40 ~ "Problemas estruturais",
        quality <= 50 ~ "Fundamentos fracos",
        TRUE ~ "Qualidade abaixo da média"
      )
    ) %>%
    rename(score_qualidade = quality) %>%
    arrange(pvp)

  message(glue("Found {nrow(value_traps)} potential value traps"))

  return(value_traps)
}

# ============================================================================
# 3. AUTOMATED ALERTS
# ============================================================================

#' Generate portfolio alerts
#'
#' Monitors portfolio holdings for quality deterioration, score drops, and risk flags.
#'
#' @param portfolio_tickers Character vector of tickers in portfolio
#' @param scores_enriched Tibble with current scores + indicators
#' @param scores_history Tibble with historical scores for change detection
#' @param thresholds Named list with alert thresholds
#' @return Tibble with alerts (ticker, tipo_alerta, severidade, valor_atual, threshold, mensagem)
#' @export
#'
#' @examples
#' \dontrun{
#' thresholds <- list(
#'   vacancia_max = 0.20,
#'   alavancagem_max = 0.50,
#'   score_drop = 10,
#'   dy_drop_pct = 20,
#'   pvp_spike_pct = 15
#' )
#' alerts <- generate_alerts_portfolio(portfolio_tickers, scores_enriched,
#'                                      scores_history, thresholds)
#' }
generate_alerts_portfolio <- function(portfolio_tickers,
                                      scores_enriched,
                                      scores_history = NULL,
                                      thresholds = list()) {

  # Default thresholds
  default_thresholds <- list(
    vacancia_max = 0.20,
    alavancagem_max = 0.50,
    score_drop = 10,
    dy_drop_pct = 20,
    pvp_spike_pct = 15
  )

  thresholds <- modifyList(default_thresholds, thresholds)

  # Filter to portfolio holdings
  portfolio_data <- scores_enriched %>%
    filter(ticker %in% portfolio_tickers)

  if (nrow(portfolio_data) == 0) {
    warning("No portfolio tickers found in scores")
    return(tibble())
  }

  alerts <- list()

  # 1. High vacancy alerts
  if ("vacancia" %in% names(portfolio_data)) {
    vacancy_alerts <- portfolio_data %>%
      filter(!is.na(vacancia), vacancia > thresholds$vacancia_max) %>%
      mutate(
        tipo_alerta = "VACANCIA_ALTA",
        severidade = case_when(
          vacancia > 0.30 ~ "CRITICO",
          vacancia > 0.25 ~ "ALTO",
          TRUE ~ "MEDIO"
        ),
        valor_atual = vacancia,
        threshold_value = thresholds$vacancia_max,
        mensagem = glue("Vacância de {round(vacancia*100, 1)}% acima do limite de {round(thresholds$vacancia_max*100, 1)}%")
      ) %>%
      select(ticker, tipo_alerta, severidade, valor_atual, threshold_value, mensagem)

    if (nrow(vacancy_alerts) > 0) {
      alerts <- append(alerts, list(vacancy_alerts))
    }
  }

  # 2. High leverage alerts
  if ("alavancagem" %in% names(portfolio_data)) {
    leverage_alerts <- portfolio_data %>%
      filter(!is.na(alavancagem), alavancagem > thresholds$alavancagem_max) %>%
      mutate(
        tipo_alerta = "ALAVANCAGEM_ALTA",
        severidade = case_when(
          alavancagem > 0.70 ~ "CRITICO",
          alavancagem > 0.60 ~ "ALTO",
          TRUE ~ "MEDIO"
        ),
        valor_atual = alavancagem,
        threshold_value = thresholds$alavancagem_max,
        mensagem = glue("Alavancagem de {round(alavancagem*100, 1)}% acima do limite de {round(thresholds$alavancagem_max*100, 1)}%")
      ) %>%
      select(ticker, tipo_alerta, severidade, valor_atual, threshold_value, mensagem)

    if (nrow(leverage_alerts) > 0) {
      alerts <- append(alerts, list(leverage_alerts))
    }
  }

  # 3. Score drop alerts (requires history)
  if (!is.null(scores_history) && nrow(scores_history) > 0) {
    # Get previous scores (30 days ago)
    previous_scores <- scores_history %>%
      filter(
        ticker %in% portfolio_tickers,
        calculated_at >= today() - days(35),
        calculated_at <= today() - days(25)
      ) %>%
      group_by(ticker) %>%
      arrange(desc(calculated_at)) %>%
      slice_head(n = 1) %>%
      ungroup() %>%
      select(ticker, previous_total_score = total_score)

    score_changes <- portfolio_data %>%
      inner_join(previous_scores, by = "ticker") %>%
      mutate(score_change = total_score - previous_total_score) %>%
      filter(score_change <= -thresholds$score_drop)

    if (nrow(score_changes) > 0) {
      score_alerts <- score_changes %>%
        mutate(
          tipo_alerta = "QUEDA_SCORE",
          severidade = case_when(
            score_change <= -20 ~ "CRITICO",
            score_change <= -15 ~ "ALTO",
            TRUE ~ "MEDIO"
          ),
          valor_atual = score_change,
          threshold_value = -thresholds$score_drop,
          mensagem = glue("Score caiu {round(abs(score_change), 1)} pontos em 30 dias")
        ) %>%
        select(ticker, tipo_alerta, severidade, valor_atual, threshold_value, mensagem)

      alerts <- append(alerts, list(score_alerts))
    }

    # 4. DY drop alerts
    previous_dy <- scores_history %>%
      filter(
        ticker %in% portfolio_tickers,
        calculated_at >= today() - days(35),
        calculated_at <= today() - days(25)
      ) %>%
      group_by(ticker) %>%
      arrange(desc(calculated_at)) %>%
      slice_head(n = 1) %>%
      ungroup() %>%
      select(ticker, previous_dy = dy_12m)

    dy_changes <- portfolio_data %>%
      inner_join(previous_dy, by = "ticker") %>%
      filter(!is.na(dy_12m), !is.na(previous_dy), previous_dy > 0) %>%
      mutate(
        dy_change_pct = ((dy_12m - previous_dy) / previous_dy) * 100
      ) %>%
      filter(dy_change_pct <= -thresholds$dy_drop_pct)

    if (nrow(dy_changes) > 0) {
      dy_alerts <- dy_changes %>%
        mutate(
          tipo_alerta = "QUEDA_DY",
          severidade = case_when(
            dy_change_pct <= -30 ~ "CRITICO",
            dy_change_pct <= -25 ~ "ALTO",
            TRUE ~ "MEDIO"
          ),
          valor_atual = dy_change_pct,
          threshold_value = -thresholds$dy_drop_pct,
          mensagem = glue("DY caiu {round(abs(dy_change_pct), 1)}% em 30 dias")
        ) %>%
        select(ticker, tipo_alerta, severidade, valor_atual, threshold_value, mensagem)

      alerts <- append(alerts, list(dy_alerts))
    }

    # 5. P/VP spike alerts
    previous_pvp <- scores_history %>%
      filter(
        ticker %in% portfolio_tickers,
        calculated_at >= today() - days(35),
        calculated_at <= today() - days(25)
      ) %>%
      group_by(ticker) %>%
      arrange(desc(calculated_at)) %>%
      slice_head(n = 1) %>%
      ungroup() %>%
      select(ticker, previous_pvp = pvp)

    pvp_spikes <- portfolio_data %>%
      inner_join(previous_pvp, by = "ticker") %>%
      filter(!is.na(pvp), !is.na(previous_pvp), previous_pvp > 0) %>%
      mutate(
        pvp_change_pct = ((pvp - previous_pvp) / previous_pvp) * 100
      ) %>%
      filter(pvp_change_pct >= thresholds$pvp_spike_pct)

    if (nrow(pvp_spikes) > 0) {
      pvp_alerts <- pvp_spikes %>%
        mutate(
          tipo_alerta = "VALORIZACAO_PVP",
          severidade = case_when(
            pvp_change_pct >= 25 ~ "ALTO",
            TRUE ~ "MEDIO"
          ),
          valor_atual = pvp_change_pct,
          threshold_value = thresholds$pvp_spike_pct,
          mensagem = glue("P/VP subiu {round(pvp_change_pct, 1)}% em 30 dias - possível sobrevalorização")
        ) %>%
        select(ticker, tipo_alerta, severidade, valor_atual, threshold_value, mensagem)

      alerts <- append(alerts, list(pvp_alerts))
    }
  }

  # Combine all alerts
  if (length(alerts) == 0) {
    message("No alerts for portfolio holdings")
    return(tibble())
  }

  all_alerts <- bind_rows(alerts) %>%
    arrange(
      factor(severidade, levels = c("CRITICO", "ALTO", "MEDIO", "BAIXO")),
      ticker
    )

  message(glue("Generated {nrow(all_alerts)} alerts for {length(portfolio_tickers)} portfolio tickers"))

  return(all_alerts)
}

# ============================================================================
# 4. CONTEXTUAL RECOMMENDATIONS
# ============================================================================

#' Generate contextual investment recommendation
#'
#' Provides personalized buy/sell/hold recommendations based on user profile.
#'
#' @param ticker Character FII ticker
#' @param scores_enriched Tibble with scores + indicators
#' @param user_profile List with perfil_risco, objetivo, horizonte_anos
#' @param current_portfolio Optional tibble with current positions
#' @return List with recommendation details
#' @export
#'
#' @examples
#' \dontrun{
#' user_profile <- list(
#'   perfil_risco = "moderado",  # "conservador" | "moderado" | "agressivo"
#'   objetivo = "renda",          # "renda" | "valorizacao" | "hibrido"
#'   horizonte_anos = 5
#' )
#'
#' rec <- recommend_actions("HGLG11", scores_enriched, user_profile)
#' }
recommend_actions <- function(ticker,
                              scores_enriched,
                              user_profile = list(
                                perfil_risco = "moderado",
                                objetivo = "renda",
                                horizonte_anos = 5
                              ),
                              current_portfolio = NULL) {

  # Get ticker data
  ticker_data <- scores_enriched %>%
    filter(ticker == !!ticker)

  if (nrow(ticker_data) == 0) {
    stop(glue("No data found for ticker {ticker}"))
  }

  ticker_data <- ticker_data[1, ]

  # Validate profile
  valid_risk <- c("conservador", "moderado", "agressivo")
  valid_obj <- c("renda", "valorizacao", "hibrido")

  if (!user_profile$perfil_risco %in% valid_risk) {
    stop(glue("perfil_risco must be one of: {paste(valid_risk, collapse=', ')}"))
  }

  if (!user_profile$objetivo %in% valid_obj) {
    stop(glue("objetivo must be one of: {paste(valid_obj, collapse=', ')}"))
  }

  # Calculate fit scores
  fit_scores <- list()

  # Risk fit
  risk_tolerance <- switch(user_profile$perfil_risco,
    "conservador" = list(max_risk = 40, min_quality = 60),
    "moderado" = list(max_risk = 60, min_quality = 50),
    "agressivo" = list(max_risk = 80, min_quality = 40)
  )

  risk_score <- ticker_data$risk
  quality_score <- ticker_data$quality

  risk_fit <- case_when(
    risk_score <= risk_tolerance$max_risk & quality_score >= risk_tolerance$min_quality ~ 100,
    risk_score <= risk_tolerance$max_risk + 10 ~ 75,
    risk_score <= risk_tolerance$max_risk + 20 ~ 50,
    TRUE ~ 25
  )

  fit_scores$risk_fit <- risk_fit

  # Objective fit
  income_score <- ticker_data$income
  valuation_score <- ticker_data$valuation

  objective_fit <- switch(user_profile$objetivo,
    "renda" = income_score * 0.7 + valuation_score * 0.3,
    "valorizacao" = valuation_score * 0.7 + income_score * 0.3,
    "hibrido" = (income_score + valuation_score) / 2
  )

  fit_scores$objective_fit <- objective_fit

  # Overall fit
  overall_fit <- (risk_fit * 0.4 + objective_fit * 0.6)

  # Determine action
  total_score <- ticker_data$total_score
  recommendation <- ticker_data$recommendation

  action <- case_when(
    overall_fit >= 75 & total_score >= 70 & recommendation == "COMPRAR" ~ "COMPRAR",
    overall_fit >= 60 & total_score >= 60 ~ "AUMENTAR",
    overall_fit < 40 | total_score < 50 ~ "VENDER",
    overall_fit < 50 | total_score < 60 ~ "REDUZIR",
    TRUE ~ "MANTER"
  )

  # Confidence level
  confianca <- min(100, (overall_fit + total_score) / 2)

  # Build justification
  justificativa_parts <- c()

  if (action %in% c("COMPRAR", "AUMENTAR")) {
    if (ticker_data$dy_12m > 0.08) {
      justificativa_parts <- c(justificativa_parts,
        glue("DY atrativo de {round(ticker_data$dy_12m*100, 1)}%"))
    }
    if (ticker_data$pvp < 1.0) {
      justificativa_parts <- c(justificativa_parts,
        glue("P/VP abaixo de 1.0 ({round(ticker_data$pvp, 2)})"))
    }
    if (quality_score >= 70) {
      justificativa_parts <- c(justificativa_parts, "Qualidade elevada")
    }
  } else if (action %in% c("VENDER", "REDUZIR")) {
    if (risk_score > 70) {
      justificativa_parts <- c(justificativa_parts, "Score de risco elevado")
    }
    if (quality_score < 50) {
      justificativa_parts <- c(justificativa_parts, "Qualidade comprometida")
    }
    if (ticker_data$pvp > 1.2) {
      justificativa_parts <- c(justificativa_parts,
        glue("P/VP alto ({round(ticker_data$pvp, 2)})"))
    }
  }

  if (length(justificativa_parts) == 0) {
    justificativa_parts <- c("Fundamentos estáveis")
  }

  justificativa <- paste(justificativa_parts, collapse = "; ")

  # Sizing suggestion
  sizing_sugerido <- case_when(
    action == "COMPRAR" & overall_fit >= 80 ~ 5.0,
    action == "COMPRAR" ~ 3.0,
    action == "AUMENTAR" ~ 2.0,
    action == "REDUZIR" ~ -2.0,
    action == "VENDER" ~ -5.0,
    TRUE ~ 0
  )

  # Price target (simple heuristic based on P/VP)
  current_price <- ticker_data$current_price
  pvp <- ticker_data$pvp

  if (!is.na(current_price) && !is.na(pvp) && pvp > 0) {
    # Target P/VP of 1.0 for value, 1.1 for growth
    target_pvp <- if_else(user_profile$objetivo == "valorizacao", 1.1, 1.0)
    preco_alvo <- current_price * (target_pvp / pvp)
  } else {
    preco_alvo <- NA_real_
  }

  # Stop loss (10% below current price for conservative, 15% for moderate, 20% for aggressive)
  stop_loss_pct <- switch(user_profile$perfil_risco,
    "conservador" = 0.10,
    "moderado" = 0.15,
    "agressivo" = 0.20
  )

  stop_loss <- if (!is.na(current_price)) {
    current_price * (1 - stop_loss_pct)
  } else {
    NA_real_
  }

  # Build result
  result <- list(
    ticker = ticker,
    acao = action,
    confianca = round(confianca, 0),
    justificativa = justificativa,
    sizing_sugerido = sizing_sugerido,
    preco_alvo = preco_alvo,
    stop_loss = stop_loss,
    fit_scores = fit_scores,
    overall_fit = overall_fit,
    user_profile = user_profile,
    generated_at = Sys.time()
  )

  return(result)
}

#' Print recommendation report
#'
#' @param recommendation Result from recommend_actions()
#' @export
print_recommendation <- function(recommendation) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat(glue("           RECOMENDAÇÃO: {recommendation$ticker}\n"))
  cat("═══════════════════════════════════════════════════════════════\n\n")

  icon <- switch(recommendation$acao,
    "COMPRAR" = "🟢",
    "AUMENTAR" = "🟢",
    "MANTER" = "🟡",
    "REDUZIR" = "🟠",
    "VENDER" = "🔴",
    "🔵"
  )

  cat(glue("{icon} AÇÃO: {recommendation$acao}\n"))
  cat(glue("   Confiança: {recommendation$confianca}%\n\n"))

  cat("💡 JUSTIFICATIVA:\n")
  cat(glue("   {recommendation$justificativa}\n\n"))

  if (!is.na(recommendation$sizing_sugerido)) {
    cat("📊 SIZING SUGERIDO:\n")
    cat(glue("   {abs(recommendation$sizing_sugerido)}% do portfolio\n\n"))
  }

  if (!is.na(recommendation$preco_alvo)) {
    cat("🎯 PREÇO ALVO:\n")
    cat(glue("   R$ {format(recommendation$preco_alvo, decimal.mark=',', nsmall=2)}\n\n"))
  }

  if (!is.na(recommendation$stop_loss)) {
    cat("🛑 STOP LOSS:\n")
    cat(glue("   R$ {format(recommendation$stop_loss, decimal.mark=',', nsmall=2)}\n\n"))
  }

  cat("📈 FIT SCORES:\n")
  cat(glue("   Risco: {round(recommendation$fit_scores$risk_fit, 0)}%\n"))
  cat(glue("   Objetivo: {round(recommendation$fit_scores$objective_fit, 0)}%\n"))
  cat(glue("   Overall: {round(recommendation$overall_fit, 0)}%\n\n"))

  cat("═══════════════════════════════════════════════════════════════\n\n")
}

# ============================================================================
# 5. CONSOLIDATED OPPORTUNITIES REPORT
# ============================================================================

#' Generate comprehensive opportunities report
#'
#' Consolidates all opportunity detection methods into a single report.
#'
#' @param scores_enriched Tibble with scores + deep indicators
#' @param portfolio_tickers Optional vector of portfolio tickers for alerts
#' @param user_profile Optional user profile for personalized recommendations
#' @param top_n Number of top opportunities to include (default: 10)
#' @return List with opportunity analysis results
#' @export
generate_opportunities_report <- function(scores_enriched,
                                          portfolio_tickers = NULL,
                                          user_profile = NULL,
                                          top_n = 10) {

  message("Generating comprehensive opportunities report...")

  report <- list()

  # 1. Top opportunities by total score
  report$oportunidades_compra <- scores_enriched %>%
    filter(recommendation %in% c("COMPRAR", "MANTER")) %>%
    arrange(desc(total_score)) %>%
    head(top_n) %>%
    select(ticker, total_score, quality, income, valuation, risk,
           dy_12m, pvp, tipo_fii, recommendation)

  # 2. Detected patterns
  message("  Detecting patterns...")

  report$padroes_detectados <- list()

  # Mean reversion
  mean_rev <- safely(detect_mean_reversion)(scores_enriched)
  if (!is.null(mean_rev$result) && nrow(mean_rev$result) > 0) {
    report$padroes_detectados$mean_reversion <- mean_rev$result %>% head(5)
  }

  # Breakouts
  breakout <- safely(detect_breakouts)(scores_enriched)
  if (!is.null(breakout$result) && nrow(breakout$result) > 0) {
    report$padroes_detectados$breakouts <- breakout$result %>% head(5)
  }

  # Momentum
  momentum <- safely(detect_momentum_positivo)(scores_enriched)
  if (!is.null(momentum$result) && nrow(momentum$result) > 0) {
    report$padroes_detectados$momentum_positivo <- momentum$result %>% head(5)
  }

  # Value traps
  traps <- safely(detect_value_traps)(scores_enriched)
  if (!is.null(traps$result) && nrow(traps$result) > 0) {
    report$padroes_detectados$value_traps <- traps$result %>% head(5)
  }

  # 3. Portfolio alerts (if portfolio provided)
  if (!is.null(portfolio_tickers)) {
    message("  Checking portfolio alerts...")
    alerts <- safely(generate_alerts_portfolio)(
      portfolio_tickers,
      scores_enriched
    )
    if (!is.null(alerts$result) && nrow(alerts$result) > 0) {
      report$alertas_portfolio <- alerts$result
    } else {
      report$alertas_portfolio <- tibble()
    }
  } else {
    report$alertas_portfolio <- NULL
  }

  # 4. Personalized recommendations (if profile provided)
  if (!is.null(user_profile)) {
    message("  Generating personalized recommendations...")

    top_tickers <- report$oportunidades_compra$ticker[1:min(5, nrow(report$oportunidades_compra))]

    recommendations <- map(top_tickers, function(tkr) {
      rec <- safely(recommend_actions)(tkr, scores_enriched, user_profile)
      if (!is.null(rec$result)) rec$result else NULL
    }) %>%
      compact()

    report$recomendacoes <- recommendations
  } else {
    report$recomendacoes <- NULL
  }

  # 5. Summary statistics
  message("  Calculating summary statistics...")

  report$summary <- list(
    total_oportunidades = nrow(report$oportunidades_compra),
    distribuicao_segmentos = report$oportunidades_compra %>%
      count(tipo_fii) %>%
      arrange(desc(n)),
    range_scores = list(
      min = min(report$oportunidades_compra$total_score, na.rm = TRUE),
      max = max(report$oportunidades_compra$total_score, na.rm = TRUE),
      mean = mean(report$oportunidades_compra$total_score, na.rm = TRUE)
    ),
    data_analise = Sys.time()
  )

  message("Report generation complete")

  return(report)
}

#' Print opportunities report
#'
#' @param report Result from generate_opportunities_report()
#' @export
print_opportunities_report <- function(report) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("              RELATÓRIO DE OPORTUNIDADES\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  # Summary
  cat("📊 RESUMO:\n")
  cat(glue("  Total de oportunidades: {report$summary$total_oportunidades}\n"))
  cat(glue("  Score médio: {round(report$summary$range_scores$mean, 1)}\n"))
  cat(glue("  Range: {round(report$summary$range_scores$min, 1)} - {round(report$summary$range_scores$max, 1)}\n"))
  cat(glue("  Data: {format(report$summary$data_analise, '%Y-%m-%d %H:%M')}\n\n"))

  # Top opportunities
  cat("🟢 TOP OPORTUNIDADES:\n\n")
  print(report$oportunidades_compra, n = Inf)
  cat("\n")

  # Patterns
  if (length(report$padroes_detectados) > 0) {
    cat("🔍 PADRÕES DETECTADOS:\n\n")

    if (!is.null(report$padroes_detectados$mean_reversion)) {
      cat("  • Mean Reversion:\n")
      print(report$padroes_detectados$mean_reversion %>%
        select(ticker, pvp, desconto_pct) %>%
        head(3))
      cat("\n")
    }

    if (!is.null(report$padroes_detectados$momentum_positivo)) {
      cat("  • Momentum Positivo:\n")
      print(report$padroes_detectados$momentum_positivo %>%
        select(ticker, momentum_3m, momentum_6m) %>%
        head(3))
      cat("\n")
    }

    if (!is.null(report$padroes_detectados$value_traps)) {
      cat("  ⚠️  Value Traps (evitar):\n")
      print(report$padroes_detectados$value_traps %>%
        select(ticker, pvp, score_qualidade, razao_evitar) %>%
        head(3))
      cat("\n")
    }
  }

  # Portfolio alerts
  if (!is.null(report$alertas_portfolio) && nrow(report$alertas_portfolio) > 0) {
    cat("⚠️  ALERTAS DE PORTFOLIO:\n\n")
    print(report$alertas_portfolio %>%
      select(ticker, tipo_alerta, severidade, mensagem))
    cat("\n")
  }

  # Recommendations
  if (!is.null(report$recomendacoes) && length(report$recomendacoes) > 0) {
    cat("💡 RECOMENDAÇÕES PERSONALIZADAS:\n\n")

    for (rec in report$recomendacoes) {
      icon <- switch(rec$acao,
        "COMPRAR" = "🟢",
        "AUMENTAR" = "🟢",
        "MANTER" = "🟡",
        "REDUZIR" = "🟠",
        "VENDER" = "🔴",
        "🔵"
      )
      cat(glue("  {icon} {rec$ticker}: {rec$acao} (confiança {rec$confianca}%)\n"))
      cat(glue("     {rec$justificativa}\n\n"))
    }
  }

  cat("═══════════════════════════════════════════════════════════════\n\n")
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Rank opportunities by method
#'
#' @param opportunities Tibble with opportunity data
#' @param method Ranking method: "score", "upside", "risk_adjusted"
#' @return Ranked tibble
#' @keywords internal
rank_opportunities <- function(opportunities, method = "score") {

  if (nrow(opportunities) == 0) {
    return(opportunities)
  }

  ranked <- switch(method,
    "score" = opportunities %>% arrange(desc(total_score)),
    "upside" = {
      if ("desconto_pct" %in% names(opportunities)) {
        opportunities %>% arrange(desc(desconto_pct))
      } else {
        opportunities %>% arrange(pvp)
      }
    },
    "risk_adjusted" = {
      if (all(c("total_score", "risk") %in% names(opportunities))) {
        opportunities %>%
          mutate(risk_adjusted_score = total_score * (1 - risk/100)) %>%
          arrange(desc(risk_adjusted_score))
      } else {
        opportunities %>% arrange(desc(total_score))
      }
    },
    opportunities %>% arrange(desc(total_score))
  )

  ranked <- ranked %>%
    mutate(rank = row_number())

  return(ranked)
}
