#' FII Deep Indicators - Advanced Multi-Factor Analysis
#'
#' Advanced indicators for FII evaluation including:
#' 1. QUALITY: Leverage, shareholder concentration, stability, efficiency
#' 2. TEMPORAL: Momentum, trend analysis, volatility indicators
#' 3. RELATIVE: Z-scores, percentile ranks, relative strength
#' 4. CONSOLIDATION: Complete indicator calculation and enrichment
#'
#' These indicators complement the basic indicators from fii_indicators.R
#' and provide deeper insights for the scoring framework.
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)
library(glue)

# ============================================================================
# QUALITY INDICATORS (Block A - Enhanced)
# ============================================================================

#' Calculate leverage ratio
#'
#' Estimates fund leverage based on CVM data (passivo/PL).
#' If passivo data not available, uses patrimonio_liquido growth as proxy.
#'
#' @param cvm_data Tibble from fii_cvm.rds with historical data for one ticker
#' @return Numeric leverage ratio (0-1+, lower is better)
#' @export
calc_alavancagem <- function(cvm_data) {
  if (nrow(cvm_data) == 0) {
    return(NA_real_)
  }

  # Check if we have passivo data (extended CVM schema)
  if ("ativo_total" %in% names(cvm_data) && "patrimonio_liquido" %in% names(cvm_data)) {
    latest <- cvm_data %>%
      arrange(desc(data_competencia)) %>%
      slice_head(n = 1)

    if (!is.na(latest$ativo_total) && !is.na(latest$patrimonio_liquido) &&
        latest$patrimonio_liquido > 0) {
      passivo <- latest$ativo_total - latest$patrimonio_liquido
      alavancagem <- passivo / latest$patrimonio_liquido
      return(max(0, alavancagem))
    }
  }

  # Proxy: If PL is very volatile, assume higher leverage risk
  # Calculate CV of patrimonio_liquido as leverage proxy
  if ("patrimonio_liquido" %in% names(cvm_data) && nrow(cvm_data) >= 3) {
    recent_data <- cvm_data %>%
      arrange(desc(data_competencia)) %>%
      head(6) %>%
      filter(!is.na(patrimonio_liquido))

    if (nrow(recent_data) >= 3) {
      cv <- sd(recent_data$patrimonio_liquido) / mean(recent_data$patrimonio_liquido)
      # Map CV to leverage proxy: CV of 0.1 = alavancagem 0.3, CV of 0.3 = alavancagem 0.9
      alavancagem_proxy <- min(cv * 3, 1.5)
      return(alavancagem_proxy)
    }
  }

  return(NA_real_)
}

#' Calculate shareholder concentration risk
#'
#' Uses inverse of numero_cotistas as concentration metric.
#' Lower number of shareholders = higher concentration risk.
#'
#' @param cvm_data Tibble from fii_cvm.rds with historical data
#' @return Numeric concentration score (0-1, lower is better = more concentrated)
#' @export
calc_concentracao_cotistas <- function(cvm_data) {
  if (nrow(cvm_data) == 0) {
    return(NA_real_)
  }

  latest <- cvm_data %>%
    arrange(desc(data_competencia)) %>%
    slice_head(n = 1)

  if (is.na(latest$numero_cotistas) || latest$numero_cotistas <= 0) {
    return(NA_real_)
  }

  # Normalize using log scale
  # 100 cotistas = 0.66, 1000 = 0.50, 10000 = 0.40, 100000 = 0.33
  concentracao <- 1 / log10(latest$numero_cotistas + 10)

  return(concentracao)
}

#' Calculate equity stability (12 months)
#'
#' Coefficient of variation of patrimonio_liquido over 12 months.
#' Lower CV = more stable equity base.
#'
#' @param cvm_data Tibble from fii_cvm.rds with historical data
#' @return Numeric CV (lower is better)
#' @export
calc_estabilidade_patrimonio <- function(cvm_data) {
  if (nrow(cvm_data) < 3) {
    return(NA_real_)
  }

  recent_data <- cvm_data %>%
    arrange(desc(data_competencia)) %>%
    head(12) %>%
    filter(!is.na(patrimonio_liquido))

  if (nrow(recent_data) < 3) {
    return(NA_real_)
  }

  cv <- sd(recent_data$patrimonio_liquido, na.rm = TRUE) /
        mean(recent_data$patrimonio_liquido, na.rm = TRUE)

  return(cv)
}

#' Calculate efficiency ratio (admin fee / equity)
#'
#' Taxa de administração as percentage of patrimonio_liquido.
#' Lower is better (more efficient management).
#'
#' @param cvm_data Tibble from fii_cvm.rds with tx_administracao field
#' @return Numeric efficiency ratio (percentage, lower is better)
#' @export
calc_taxa_eficiencia <- function(cvm_data) {
  if (nrow(cvm_data) == 0) {
    return(NA_real_)
  }

  latest <- cvm_data %>%
    arrange(desc(data_competencia)) %>%
    slice_head(n = 1)

  if (is.na(latest$tx_administracao) || is.na(latest$patrimonio_liquido)) {
    return(NA_real_)
  }

  if (latest$patrimonio_liquido <= 0) {
    return(NA_real_)
  }

  # If tx_administracao is already in percentage, use as-is
  # Otherwise calculate as ratio * 100
  eficiencia <- latest$tx_administracao

  # Handle cases where tx_admin is annual absolute value vs percentage
  if (eficiencia > 5) {
    # Assume it's annual absolute value, convert to percentage
    eficiencia <- (eficiencia / latest$patrimonio_liquido) * 100
  }

  return(eficiencia)
}

# ============================================================================
# TEMPORAL INDICATORS (Trend Analysis)
# ============================================================================

#' Calculate momentum for multiple windows
#'
#' Calculates rate of change over different time windows (3M, 6M, 12M).
#' Returns named list with momentum values for each window.
#'
#' @param indicator_history Tibble with date and indicator_value columns
#' @param windows Numeric vector of window sizes in months (default: c(3, 6, 12))
#' @return Named list with momentum values (percentage change)
#' @export
calc_momentum <- function(indicator_history, windows = c(3, 6, 12)) {
  if (nrow(indicator_history) < 2 ||
      !all(c("date", "indicator_value") %in% names(indicator_history))) {
    return(setNames(rep(NA_real_, length(windows)), paste0("momentum_", windows, "m")))
  }

  sorted_data <- indicator_history %>%
    arrange(desc(date)) %>%
    filter(!is.na(indicator_value))

  if (nrow(sorted_data) < 2) {
    return(setNames(rep(NA_real_, length(windows)), paste0("momentum_", windows, "m")))
  }

  current_value <- sorted_data$indicator_value[1]
  current_date <- sorted_data$date[1]

  momentum_values <- map_dbl(windows, function(window) {
    target_date <- current_date - months(window)

    # Find closest date to target
    past_data <- sorted_data %>%
      filter(date <= target_date) %>%
      arrange(desc(date)) %>%
      slice_head(n = 1)

    if (nrow(past_data) == 0 || past_data$indicator_value == 0) {
      return(NA_real_)
    }

    momentum <- ((current_value - past_data$indicator_value) / past_data$indicator_value) * 100
    return(momentum)
  })

  names(momentum_values) <- paste0("momentum_", windows, "m")
  return(as.list(momentum_values))
}

#' Calculate trend score using linear regression
#'
#' Fits linear regression to indicator time series and returns slope.
#' Positive slope = upward trend, negative = downward trend.
#'
#' @param indicator_history Tibble with date and indicator_value columns
#' @param min_points Minimum number of points required (default: 6)
#' @return Numeric slope coefficient (trend direction and strength)
#' @export
calc_trend_score <- function(indicator_history, min_points = 6) {
  if (nrow(indicator_history) < min_points ||
      !all(c("date", "indicator_value") %in% names(indicator_history))) {
    return(NA_real_)
  }

  clean_data <- indicator_history %>%
    filter(!is.na(indicator_value), !is.na(date)) %>%
    arrange(date) %>%
    mutate(time_index = as.numeric(date - min(date)))

  if (nrow(clean_data) < min_points) {
    return(NA_real_)
  }

  tryCatch({
    model <- lm(indicator_value ~ time_index, data = clean_data)
    slope <- coef(model)[2]

    # Normalize slope by mean value to get relative trend
    mean_val <- mean(clean_data$indicator_value, na.rm = TRUE)
    if (mean_val == 0) {
      return(NA_real_)
    }

    relative_slope <- (slope / mean_val) * 365.25 # Annualized
    return(relative_slope)
  }, error = function(e) {
    return(NA_real_)
  })
}

#' Calculate volatility indicators for key metrics
#'
#' Calculates volatility (standard deviation) for multiple indicators.
#' Returns named list with volatility values.
#'
#' @param indicator_history Tibble with indicator values over time
#' @param indicators Character vector of column names to calculate volatility for
#' @return Named list with volatility values
#' @export
calc_volatility_indicators <- function(indicator_history,
                                        indicators = c("dy", "rentabilidade")) {
  if (nrow(indicator_history) < 3) {
    return(setNames(rep(NA_real_, length(indicators)), paste0("vol_", indicators)))
  }

  volatility_values <- map(indicators, function(ind) {
    if (!ind %in% names(indicator_history)) {
      return(NA_real_)
    }

    values <- indicator_history[[ind]]
    clean_values <- values[!is.na(values)]

    if (length(clean_values) < 3) {
      return(NA_real_)
    }

    # Calculate coefficient of variation (CV)
    mean_val <- mean(clean_values)
    if (mean_val == 0) {
      return(NA_real_)
    }

    cv <- sd(clean_values) / abs(mean_val)
    return(cv)
  })

  names(volatility_values) <- paste0("vol_", indicators)
  return(volatility_values)
}

# ============================================================================
# RELATIVE INDICATORS (Segment Comparison)
# ============================================================================

#' Calculate z-score vs segment
#'
#' Calculates how many standard deviations a value is from segment mean.
#'
#' @param value Numeric value for the ticker
#' @param segment_data Numeric vector of segment values
#' @return Numeric z-score
#' @export
calc_zscore_segment <- function(value, segment_data) {
  if (is.na(value) || length(segment_data) < 3) {
    return(NA_real_)
  }

  clean_data <- segment_data[!is.na(segment_data)]

  if (length(clean_data) < 3) {
    return(NA_real_)
  }

  mean_val <- mean(clean_data)
  sd_val <- sd(clean_data)

  if (sd_val == 0) {
    return(0)
  }

  z_score <- (value - mean_val) / sd_val
  return(z_score)
}

#' Calculate percentile rank within segment
#'
#' Returns percentile rank (0-100) of a value within segment.
#'
#' @param value Numeric value for the ticker
#' @param segment_data Numeric vector of segment values
#' @return Numeric percentile (0-100)
#' @export
calc_percentile_rank <- function(value, segment_data) {
  if (is.na(value) || length(segment_data) < 2) {
    return(NA_real_)
  }

  clean_data <- segment_data[!is.na(segment_data)]

  if (length(clean_data) < 2) {
    return(NA_real_)
  }

  percentile <- (sum(clean_data <= value) / length(clean_data)) * 100
  return(percentile)
}

#' Calculate relative strength vs peers
#'
#' Measures performance relative to segment average over window.
#' Positive = outperformance, negative = underperformance.
#'
#' @param ticker Character ticker code
#' @param all_data Tibble with ticker, date, indicator_value for all FIIs
#' @param window Integer, window size in months (default: 12)
#' @return Numeric relative strength (percentage outperformance)
#' @export
calc_relative_strength <- function(ticker, all_data, window = 12) {
  if (nrow(all_data) == 0 ||
      !all(c("ticker", "date", "indicator_value") %in% names(all_data))) {
    return(NA_real_)
  }

  cutoff_date <- today() - months(window)

  # Get ticker performance
  ticker_data <- all_data %>%
    filter(ticker == !!ticker, date >= cutoff_date) %>%
    arrange(date)

  if (nrow(ticker_data) < 2) {
    return(NA_real_)
  }

  ticker_start <- ticker_data$indicator_value[1]
  ticker_end <- ticker_data$indicator_value[nrow(ticker_data)]

  if (ticker_start == 0) {
    return(NA_real_)
  }

  ticker_return <- ((ticker_end - ticker_start) / ticker_start) * 100

  # Get segment average performance
  segment_data <- all_data %>%
    filter(ticker != !!ticker, date >= cutoff_date) %>%
    group_by(ticker) %>%
    arrange(date) %>%
    summarise(
      start_val = first(indicator_value),
      end_val = last(indicator_value),
      .groups = "drop"
    ) %>%
    filter(start_val > 0) %>%
    mutate(return_pct = ((end_val - start_val) / start_val) * 100)

  if (nrow(segment_data) < 3) {
    return(NA_real_)
  }

  segment_avg_return <- mean(segment_data$return_pct, na.rm = TRUE)

  relative_strength <- ticker_return - segment_avg_return
  return(relative_strength)
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Get tickers from same segment
#'
#' Returns list of tickers that belong to same segment as target ticker.
#'
#' @param ticker Character ticker code
#' @param all_data Tibble with ticker and tipo_fii/segmento columns
#' @return Character vector of peer tickers (excluding input ticker)
#' @export
get_segment_peers <- function(ticker, all_data) {
  if (nrow(all_data) == 0 || !ticker %in% all_data$ticker) {
    return(character(0))
  }

  # Try tipo_fii first, fallback to segmento
  segment_col <- if ("tipo_fii" %in% names(all_data)) "tipo_fii" else "segmento"

  if (!segment_col %in% names(all_data)) {
    return(character(0))
  }

  target_segment <- all_data %>%
    filter(ticker == !!ticker) %>%
    pull(!!segment_col) %>%
    first()

  if (is.na(target_segment)) {
    return(character(0))
  }

  peers <- all_data %>%
    filter(!!sym(segment_col) == target_segment, ticker != !!ticker) %>%
    pull(ticker) %>%
    unique()

  return(peers)
}

#' Calculate segment statistics for an indicator
#'
#' Returns summary statistics for a segment: mean, sd, median, quartiles.
#'
#' @param segment_data Tibble with indicator values for segment
#' @param indicator Character, column name of indicator
#' @return List with segment statistics
#' @export
calculate_segment_statistics <- function(segment_data, indicator) {
  if (nrow(segment_data) == 0 || !indicator %in% names(segment_data)) {
    return(list(
      mean = NA_real_,
      sd = NA_real_,
      median = NA_real_,
      q25 = NA_real_,
      q75 = NA_real_,
      n = 0
    ))
  }

  values <- segment_data[[indicator]]
  clean_values <- values[!is.na(values)]

  if (length(clean_values) < 3) {
    return(list(
      mean = NA_real_,
      sd = NA_real_,
      median = NA_real_,
      q25 = NA_real_,
      q75 = NA_real_,
      n = length(clean_values)
    ))
  }

  list(
    mean = mean(clean_values),
    sd = sd(clean_values),
    median = median(clean_values),
    q25 = quantile(clean_values, 0.25, na.rm = TRUE),
    q75 = quantile(clean_values, 0.75, na.rm = TRUE),
    n = length(clean_values)
  )
}

#' Normalize value to target scale
#'
#' Normalizes value from [min_val, max_val] to [0, scale].
#'
#' @param value Numeric value to normalize
#' @param min_val Numeric minimum of input range
#' @param max_val Numeric maximum of input range
#' @param scale Numeric target scale (default: 100)
#' @return Numeric normalized value
#' @export
normalize_to_scale <- function(value, min_val, max_val, scale = 100) {
  if (is.na(value) || is.na(min_val) || is.na(max_val)) {
    return(NA_real_)
  }

  if (max_val == min_val) {
    return(scale / 2)
  }

  normalized <- ((value - min_val) / (max_val - min_val)) * scale
  normalized <- pmax(0, pmin(scale, normalized))

  return(normalized)
}

# ============================================================================
# CONSOLIDATION FUNCTIONS
# ============================================================================

#' Calculate all deep indicators for a ticker
#'
#' Comprehensive function that calculates all advanced indicators.
#' Requires cache with: cvm_data, scores_history (optional), fiis (for segment).
#'
#' @param ticker Character ticker code
#' @param cache List with cvm_data, fiis, and optional scores_history
#' @return Tibble with one row and all deep indicators as columns
#' @export
calculate_all_deep_indicators <- function(ticker, cache) {

  # Initialize result with ticker
  result <- tibble(ticker = ticker)

  # Get CVM data for this ticker
  cvm_data <- if (!is.null(cache$cvm_data)) {
    cache$cvm_data %>% filter(ticker == !!ticker)
  } else {
    tibble()
  }

  # Get segment info
  segment <- if (!is.null(cache$fiis)) {
    cache$fiis %>%
      filter(ticker == !!ticker) %>%
      pull(tipo_fii) %>%
      first()
  } else {
    NA_character_
  }

  # ========== QUALITY INDICATORS ==========
  result$alavancagem <- calc_alavancagem(cvm_data)
  result$concentracao_cotistas <- calc_concentracao_cotistas(cvm_data)
  result$estabilidade_patrimonio <- calc_estabilidade_patrimonio(cvm_data)
  result$taxa_eficiencia <- calc_taxa_eficiencia(cvm_data)

  # ========== TEMPORAL INDICATORS ==========
  # Momentum based on DY history
  if (!is.null(cache$scores_history)) {
    dy_history <- cache$scores_history %>%
      filter(ticker == !!ticker) %>%
      select(date = calculated_at, indicator_value = dy_12m) %>%
      filter(!is.na(indicator_value))

    if (nrow(dy_history) >= 2) {
      momentum_list <- calc_momentum(dy_history, windows = c(3, 6, 12))
      result <- bind_cols(result, as_tibble(momentum_list))

      result$trend_dy <- calc_trend_score(dy_history)
    } else {
      result$momentum_3m <- NA_real_
      result$momentum_6m <- NA_real_
      result$momentum_12m <- NA_real_
      result$trend_dy <- NA_real_
    }

    # Volatility of DY and rentabilidade from CVM
    if (nrow(cvm_data) >= 3) {
      vol_data <- cvm_data %>%
        arrange(desc(data_competencia)) %>%
        head(12) %>%
        select(dy = dividend_yield, rentabilidade = rentabilidade_mensal)

      vol_indicators <- calc_volatility_indicators(vol_data, c("dy", "rentabilidade"))
      result <- bind_cols(result, as_tibble(vol_indicators))
    } else {
      result$vol_dy <- NA_real_
      result$vol_rentabilidade <- NA_real_
    }
  } else {
    result$momentum_3m <- NA_real_
    result$momentum_6m <- NA_real_
    result$momentum_12m <- NA_real_
    result$trend_dy <- NA_real_
    result$vol_dy <- NA_real_
    result$vol_rentabilidade <- NA_real_
  }

  # ========== RELATIVE INDICATORS ==========
  if (!is.null(cache$fiis) && !is.na(segment)) {
    # Get segment peers
    peers <- get_segment_peers(ticker, cache$fiis)

    # Calculate z-scores for key metrics
    if (length(peers) >= 3 && !is.null(cache$scores)) {
      segment_scores <- cache$scores %>%
        filter(ticker %in% c(!!ticker, peers))

      ticker_dy <- segment_scores %>%
        filter(ticker == !!ticker) %>%
        pull(dy_12m) %>%
        first()

      ticker_pvp <- segment_scores %>%
        filter(ticker == !!ticker) %>%
        pull(pvp) %>%
        first()

      peer_dy <- segment_scores %>%
        filter(ticker %in% peers) %>%
        pull(dy_12m)

      peer_pvp <- segment_scores %>%
        filter(ticker %in% peers) %>%
        pull(pvp)

      result$zscore_dy <- calc_zscore_segment(ticker_dy, peer_dy)
      result$zscore_pvp <- calc_zscore_segment(ticker_pvp, peer_pvp)
      result$percentile_dy <- calc_percentile_rank(ticker_dy, peer_dy)
      result$percentile_pvp <- calc_percentile_rank(ticker_pvp, peer_pvp)

      # Relative strength
      if (!is.null(cache$scores_history)) {
        strength_data <- cache$scores_history %>%
          filter(ticker %in% c(!!ticker, peers)) %>%
          select(ticker, date = calculated_at, indicator_value = total_score)

        result$relative_strength_12m <- calc_relative_strength(ticker, strength_data, 12)
      } else {
        result$relative_strength_12m <- NA_real_
      }
    } else {
      result$zscore_dy <- NA_real_
      result$zscore_pvp <- NA_real_
      result$percentile_dy <- NA_real_
      result$percentile_pvp <- NA_real_
      result$relative_strength_12m <- NA_real_
    }
  } else {
    result$zscore_dy <- NA_real_
    result$zscore_pvp <- NA_real_
    result$percentile_dy <- NA_real_
    result$percentile_pvp <- NA_real_
    result$relative_strength_12m <- NA_real_
  }

  return(result)
}

#' Enrich scores with deep indicators
#'
#' Takes existing fii_scores.rds and adds deep indicator columns.
#' Returns enriched tibble ready to be saved back.
#'
#' @param basic_scores Tibble from fii_scores.rds
#' @param cache List with cvm_data, fiis, scores_history
#' @return Tibble with additional deep indicator columns
#' @export
enrich_scores_with_deep_indicators <- function(basic_scores, cache) {

  if (nrow(basic_scores) == 0) {
    warning("Empty scores tibble provided")
    return(basic_scores)
  }

  # Add scores to cache for relative calculations
  cache$scores <- basic_scores

  message(glue("Calculating deep indicators for {nrow(basic_scores)} FIIs..."))

  # Progress bar
  pb <- txtProgressBar(min = 0, max = nrow(basic_scores), style = 3)

  # Calculate deep indicators for each ticker
  deep_indicators_list <- map(seq_len(nrow(basic_scores)), function(i) {
    ticker <- basic_scores$ticker[i]
    setTxtProgressBar(pb, i)

    tryCatch({
      calculate_all_deep_indicators(ticker, cache)
    }, error = function(e) {
      warning(glue("Failed to calculate deep indicators for {ticker}: {e$message}"))
      tibble(ticker = ticker)
    })
  })

  close(pb)

  # Combine results
  deep_indicators <- bind_rows(deep_indicators_list)

  # Join with basic scores
  enriched_scores <- basic_scores %>%
    left_join(deep_indicators, by = "ticker")

  message(glue("Added {ncol(deep_indicators) - 1} deep indicator columns"))

  return(enriched_scores)
}

#' Load cache for deep indicator calculation
#'
#' Helper function to load all necessary data for deep indicators.
#' Loads: cvm_data, fiis, scores, scores_history (if available).
#'
#' @param cvm_file Path to fii_cvm.rds (default: data/fii_cvm.rds)
#' @param scores_file Path to fii_scores.rds (default: data/fii_scores.rds)
#' @param fiis_file Path to fiis.rds (default: data/fiis.rds)
#' @param history_file Path to scores history (optional)
#' @return List with cache data
#' @export
load_deep_indicators_cache <- function(cvm_file = "data/fii_cvm.rds",
                                        scores_file = "data/fii_scores.rds",
                                        fiis_file = "data/fiis.rds",
                                        history_file = NULL) {
  cache <- list()

  # Load CVM data
  if (file.exists(cvm_file)) {
    cache$cvm_data <- readRDS(cvm_file)
    message(glue("Loaded CVM data: {nrow(cache$cvm_data)} rows"))
  } else {
    warning(glue("CVM data file not found: {cvm_file}"))
    cache$cvm_data <- NULL
  }

  # Load FII info
  if (file.exists(fiis_file)) {
    cache$fiis <- readRDS(fiis_file)
    message(glue("Loaded FII info: {nrow(cache$fiis)} FIIs"))
  } else {
    warning(glue("FII info file not found: {fiis_file}"))
    cache$fiis <- NULL
  }

  # Load scores
  if (file.exists(scores_file)) {
    cache$scores <- readRDS(scores_file)
    message(glue("Loaded scores: {nrow(cache$scores)} FIIs"))
  } else {
    warning(glue("Scores file not found: {scores_file}"))
    cache$scores <- NULL
  }

  # Load history if available
  if (!is.null(history_file) && file.exists(history_file)) {
    cache$scores_history <- readRDS(history_file)
    message(glue("Loaded scores history: {nrow(cache$scores_history)} records"))
  } else {
    cache$scores_history <- NULL
    message("No scores history available (momentum/trend indicators will be NA)")
  }

  return(cache)
}
