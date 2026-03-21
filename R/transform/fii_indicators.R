#' FII Indicators - Individual Calculation Functions
#'
#' Calculate specific indicators for FII analysis based on the 4-block framework:
#' - Block A: Quality (vacância, concentração, prazo, inadimplência, alavancagem)
#' - Block B: Income (DY 12M, estabilidade, payout, cobertura)
#' - Block C: Valuation (P/VP, desconto vs pares, yield spread)
#' - Block D: Risk (liquidez, volatilidade, drawdown, correlações)
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(lubridate)

# ============================================================================
# BLOCK B: INCOME INDICATORS
# ============================================================================

#' Calculate dividend yield (12 months)
#'
#' @param income_history Tibble with columns: rendimento, data_pagamento
#' @param current_price Current price per share
#' @return Numeric DY percentage
#' @export
calc_dy_12m <- function(income_history, current_price) {
  if (nrow(income_history) == 0 || is.na(current_price)) {
    return(NA_real_)
  }

  total_dividends <- income_history %>%
    filter(data_pagamento >= today() - months(12)) %>%
    summarise(total = sum(rendimento, na.rm = TRUE)) %>%
    pull(total)

  dy <- (total_dividends / current_price) * 100
  return(dy)
}

#' Calculate dividend stability (coefficient of variation)
#'
#' @param income_history Tibble with rendimento column
#' @return Numeric CV (lower is better)
#' @export
calc_dividend_stability <- function(income_history) {
  if (nrow(income_history) < 3) {
    return(NA_real_)
  }

  cv <- sd(income_history$rendimento, na.rm = TRUE) /
        mean(income_history$rendimento, na.rm = TRUE)

  return(cv)
}

#' Calculate dividend growth rate (CAGR)
#'
#' @param income_history Tibble with rendimento and data_pagamento
#' @param periods Number of periods to analyze (default: 12 months)
#' @return Numeric CAGR percentage
#' @export
calc_dividend_growth <- function(income_history, periods = 12) {
  if (nrow(income_history) < periods) {
    return(NA_real_)
  }

  income_sorted <- income_history %>%
    arrange(data_pagamento)

  first_payments <- income_sorted %>%
    head(3) %>%
    summarise(mean = mean(rendimento, na.rm = TRUE)) %>%
    pull(mean)

  last_payments <- income_sorted %>%
    tail(3) %>%
    summarise(mean = mean(rendimento, na.rm = TRUE)) %>%
    pull(mean)

  n_years <- as.numeric(difftime(max(income_sorted$data_pagamento),
                                  min(income_sorted$data_pagamento),
                                  units = "days")) / 365.25

  if (n_years <= 0 || first_payments <= 0) {
    return(NA_real_)
  }

  cagr <- ((last_payments / first_payments)^(1/n_years) - 1) * 100
  return(cagr)
}

# ============================================================================
# BLOCK C: VALUATION INDICATORS
# ============================================================================

#' Calculate P/VP ratio
#'
#' @param current_price Current market price
#' @param patrimonio_cota Book value per share
#' @return Numeric P/VP ratio
#' @export
calc_pvp <- function(current_price, patrimonio_cota) {
  if (is.na(current_price) || is.na(patrimonio_cota) || patrimonio_cota == 0) {
    return(NA_real_)
  }

  return(current_price / patrimonio_cota)
}

#' Calculate yield spread vs benchmark (NTN-B or CDI)
#'
#' @param dy_12m Dividend yield (12 months)
#' @param benchmark_rate Benchmark rate (default: 6% - approximate CDI)
#' @return Numeric yield spread in percentage points
#' @export
calc_yield_spread <- function(dy_12m, benchmark_rate = 6.0) {
  if (is.na(dy_12m)) {
    return(NA_real_)
  }

  return(dy_12m - benchmark_rate)
}

#' Calculate discount/premium vs NAV
#'
#' @param pvp P/VP ratio
#' @return Numeric discount (-) or premium (+) percentage
#' @export
calc_discount_premium <- function(pvp) {
  if (is.na(pvp)) {
    return(NA_real_)
  }

  return((pvp - 1) * 100)
}

# ============================================================================
# BLOCK D: RISK INDICATORS
# ============================================================================

#' Calculate price volatility (12 months)
#'
#' @param quotations_history Tibble with price and date columns
#' @return Numeric volatility (standard deviation of returns)
#' @export
calc_volatility <- function(quotations_history) {
  if (nrow(quotations_history) < 20) {
    return(NA_real_)
  }

  returns <- quotations_history %>%
    arrange(date) %>%
    mutate(return = (price / lag(price)) - 1) %>%
    filter(!is.na(return))

  volatility <- sd(returns$return, na.rm = TRUE) * 100
  return(volatility)
}

#' Calculate maximum drawdown (12 months)
#'
#' @param quotations_history Tibble with price and date columns
#' @return Numeric max drawdown percentage (negative value)
#' @export
calc_max_drawdown <- function(quotations_history) {
  if (nrow(quotations_history) < 2) {
    return(NA_real_)
  }

  prices <- quotations_history %>%
    arrange(date) %>%
    mutate(
      cummax = cummax(price),
      drawdown = (price / cummax - 1) * 100
    )

  return(min(prices$drawdown, na.rm = TRUE))
}

#' Calculate liquidity score based on daily volume
#'
#' @param quotations_history Tibble with date column
#' @return Numeric liquidity score (0-100, higher is better)
#' @export
calc_liquidity_score <- function(quotations_history) {
  if (nrow(quotations_history) < 20) {
    return(NA_real_)
  }

  # Count trading days in last 12 months
  trading_days <- quotations_history %>%
    filter(date >= today() - months(12)) %>%
    nrow()

  # Expected trading days (approx 252 per year)
  expected_days <- as.numeric(difftime(today(),
                                       today() - months(12),
                                       units = "days")) * (252/365)

  # Liquidity as % of expected trading days
  liquidity <- min((trading_days / expected_days) * 100, 100)

  return(liquidity)
}

# ============================================================================
# BLOCK A: QUALITY INDICATORS (from market data)
# ============================================================================

#' Calculate concentration risk based on IFIX participation
#'
#' @param participacao_ifix IFIX participation percentage
#' @return Numeric concentration score (0-100, lower is more concentrated)
#' @export
calc_concentration_score <- function(participacao_ifix) {
  if (is.na(participacao_ifix)) {
    return(50) # Neutral if no data
  }

  # Higher IFIX participation = more liquid/established = lower concentration risk
  score <- min(participacao_ifix * 10, 100)
  return(score)
}

#' Estimate quality score based on available market data
#'
#' @param numero_cotista Number of shareholders
#' @param patrimonio Total fund assets
#' @param administrador Fund administrator
#' @return Numeric quality score (0-100)
#' @export
calc_quality_score_basic <- function(numero_cotista, patrimonio, administrador) {
  score <- 50 # Base score

  # More shareholders = better (up to +20 points)
  if (!is.na(numero_cotista)) {
    shareholder_score <- min(log10(numero_cotista) * 5, 20)
    score <- score + shareholder_score
  }

  # Larger fund = better (up to +20 points)
  if (!is.na(patrimonio) && patrimonio > 0) {
    size_score <- min(log10(patrimonio / 1e6) * 4, 20)
    score <- score + size_score
  }

  # Known administrator (placeholder - could be enhanced with a whitelist)
  if (!is.na(administrador) && nchar(administrador) > 0) {
    score <- score + 10
  }

  return(min(score, 100))
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Normalize indicator to 0-100 scale using z-score
#'
#' @param value Indicator value
#' @param mean_val Mean of the segment
#' @param sd_val Standard deviation of the segment
#' @param higher_is_better TRUE if higher values are better
#' @return Numeric normalized score (0-100)
#' @export
normalize_indicator <- function(value, mean_val, sd_val, higher_is_better = TRUE) {
  if (is.na(value) || is.na(mean_val) || is.na(sd_val) || sd_val == 0) {
    return(50) # Neutral score if no data
  }

  # Calculate z-score
  z_score <- (value - mean_val) / sd_val

  # Invert if lower is better
  if (!higher_is_better) {
    z_score <- -z_score
  }

  # Convert to 0-100 scale (using standard normal CDF approximation)
  # z=-3 -> 0, z=0 -> 50, z=+3 -> 100
  score <- 50 + (z_score * 16.67)
  score <- pmax(0, pmin(100, score))

  return(score)
}

#' Calculate all basic indicators for a FII
#'
#' @param fii_data Result from get_comprehensive_fii_data()
#' @param cache Cached data for comparisons
#' @return Tibble with all calculated indicators
#' @export
calculate_all_indicators <- function(fii_data, cache = NULL) {
  base <- fii_data$base
  income_hist <- base$income_history[[1]]

  # Get quotations history for volatility/drawdown
  if (is.null(cache)) {
    cache <- load_cached_data()
  }

  quotations_hist <- cache$quotations %>%
    filter(ticker == fii_data$ticker,
           date >= today() - months(12))

  tibble(
    ticker = fii_data$ticker,

    # Block B: Income
    dy_12m = calc_dy_12m(income_hist, base$price),
    dividend_stability = calc_dividend_stability(income_hist),
    dividend_growth = calc_dividend_growth(income_hist),

    # Block C: Valuation
    pvp = calc_pvp(base$price, base$patrimonio_cota),
    discount_premium = calc_discount_premium(calc_pvp(base$price, base$patrimonio_cota)),
    yield_spread = calc_yield_spread(calc_dy_12m(income_hist, base$price)),

    # Block D: Risk
    volatility = calc_volatility(quotations_hist),
    max_drawdown = calc_max_drawdown(quotations_hist),
    liquidity_score = calc_liquidity_score(quotations_hist),

    # Block A: Quality (basic)
    concentration_score = calc_concentration_score(base$participacao_ifix),
    quality_score_basic = calc_quality_score_basic(
      base$numero_cotista,
      base$patrimonio,
      base$administrador
    )
  )
}
