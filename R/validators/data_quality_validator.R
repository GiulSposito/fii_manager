# data_quality_validator.R
# Validação de qualidade de dados
# Verifica ranges, valores faltantes, outliers, etc.

library(dplyr)
library(lubridate)
library(glue)

#' Validate Data Quality
#'
#' Performs comprehensive data quality checks.
#'
#' @param data Data frame to validate
#' @param data_type Type of data (income, quotations, portfolio, etc.)
#' @param config Validation config
#' @param logger Logger instance
#' @return Validation result list
#' @export
validate_data_quality <- function(data, data_type, config = NULL, logger = NULL) {
  if (!is.null(logger)) {
    logger$info(glue("Validating data quality: {data_type}"))
  }

  issues <- list()

  # Run checks based on data type
  if (data_type == "income") {
    issues <- c(issues, validate_income_quality(data, config, logger))
  } else if (data_type == "quotations") {
    issues <- c(issues, validate_quotations_quality(data, config, logger))
  } else if (data_type == "portfolio") {
    issues <- c(issues, validate_portfolio_quality(data, config, logger))
  } else if (data_type == "fii_indicators") {
    issues <- c(issues, validate_indicators_quality(data, config, logger))
  }

  # Generic checks
  issues <- c(issues, validate_generic_quality(data, data_type, logger))

  valid <- length(issues) == 0

  if (!is.null(logger)) {
    if (valid) {
      logger$info(glue("✓ Data quality OK: {data_type}"))
    } else {
      logger$warn(glue("✗ Data quality issues found: {data_type} ({length(issues)} issues)"))
      for (issue in issues[1:min(5, length(issues))]) {
        logger$warn(glue("  - {issue}"))
      }
      if (length(issues) > 5) {
        logger$warn(glue("  ... and {length(issues) - 5} more issues"))
      }
    }
  }

  list(
    valid = valid,
    issues = issues,
    data_type = data_type,
    row_count = nrow(data)
  )
}

#' Validate Income Data Quality
#'
#' @keywords internal
validate_income_quality <- function(data, config, logger) {
  issues <- character(0)

  # Check for negative rendimento
  if (config$validation$data_quality$check_negative_values %||% TRUE) {
    negative_rendimento <- sum(data$rendimento < 0, na.rm = TRUE)
    if (negative_rendimento > 0) {
      issues <- c(issues, glue("{negative_rendimento} negative rendimento values"))
    }
  }

  # Check for future dates
  if (config$validation$data_quality$check_future_dates %||% TRUE) {
    max_future_days <- config$validation$data_quality$max_future_days %||% 90

    future_base <- sum(data$data_base > Sys.Date() + days(max_future_days), na.rm = TRUE)
    if (future_base > 0) {
      issues <- c(issues, glue("{future_base} data_base values too far in future"))
    }

    future_pagamento <- sum(data$data_pagamento > Sys.Date() + days(max_future_days), na.rm = TRUE)
    if (future_pagamento > 0) {
      issues <- c(issues, glue("{future_pagamento} data_pagamento values too far in future"))
    }
  }

  # Check for invalid tickers
  if (config$validation$data_quality$check_invalid_tickers %||% TRUE) {
    invalid_tickers <- sum(!grepl("^[A-Z]{4}11$", data$ticker), na.rm = TRUE)
    if (invalid_tickers > 0) {
      issues <- c(issues, glue("{invalid_tickers} invalid ticker formats"))
    }
  }

  # Check for unrealistic DY values
  unrealistic_dy <- sum(data$dy > 0.5 | data$dy < 0, na.rm = TRUE)
  if (unrealistic_dy > 0) {
    issues <- c(issues, glue("{unrealistic_dy} unrealistic DY values (>50% or <0%)"))
  }

  # Check data_pagamento >= data_base
  invalid_dates <- sum(data$data_pagamento < data$data_base, na.rm = TRUE)
  if (invalid_dates > 0) {
    issues <- c(issues, glue("{invalid_dates} data_pagamento before data_base"))
  }

  issues
}

#' Validate Quotations Data Quality
#'
#' @keywords internal
validate_quotations_quality <- function(data, config, logger) {
  issues <- character(0)

  # Check for negative prices
  negative_prices <- sum(data$price <= 0, na.rm = TRUE)
  if (negative_prices > 0) {
    issues <- c(issues, glue("{negative_prices} non-positive price values"))
  }

  # Check for extreme price changes (>50% day-over-day)
  data_sorted <- data %>%
    arrange(ticker, date) %>%
    group_by(ticker) %>%
    mutate(pct_change = (price / lag(price)) - 1) %>%
    ungroup()

  extreme_changes <- sum(abs(data_sorted$pct_change) > 0.5, na.rm = TRUE)
  if (extreme_changes > 0) {
    issues <- c(issues, glue("{extreme_changes} extreme price changes (>50%)"))
  }

  # Check for future dates
  future_dates <- sum(data$date > Sys.time() + days(1), na.rm = TRUE)
  if (future_dates > 0) {
    issues <- c(issues, glue("{future_dates} future date values"))
  }

  issues
}

#' Validate Portfolio Data Quality
#'
#' @keywords internal
validate_portfolio_quality <- function(data, config, logger) {
  issues <- character(0)

  # Check for negative volume
  negative_volume <- sum(data$volume < 0, na.rm = TRUE)
  if (negative_volume > 0) {
    issues <- c(issues, glue("{negative_volume} negative volume values"))
  }

  # Check for negative price
  negative_price <- sum(data$price <= 0, na.rm = TRUE)
  if (negative_price > 0) {
    issues <- c(issues, glue("{negative_price} non-positive price values"))
  }

  # Check for negative value
  negative_value <- sum(data$value < 0, na.rm = TRUE)
  if (negative_value > 0) {
    issues <- c(issues, glue("{negative_value} negative value"))
  }

  # Check value = volume * price (approx)
  data$expected_value <- data$volume * data$price
  value_mismatch <- sum(abs(data$value - data$expected_value) > 0.01, na.rm = TRUE)
  if (value_mismatch > 0) {
    issues <- c(issues, glue("{value_mismatch} value != volume * price mismatches"))
  }

  issues
}

#' Validate Indicators Data Quality
#'
#' @keywords internal
validate_indicators_quality <- function(data, config, logger) {
  issues <- character(0)

  # Check for negative valor_atual
  negative_valor <- sum(data$valor_atual <= 0, na.rm = TRUE)
  if (negative_valor > 0) {
    issues <- c(issues, glue("{negative_valor} non-positive valor_atual"))
  }

  # Check for unrealistic P/VP (should be 0-3 typically)
  unrealistic_pvp <- sum(data$p_vp < 0 | data$p_vp > 5, na.rm = TRUE)
  if (unrealistic_pvp > 0) {
    issues <- c(issues, glue("{unrealistic_pvp} unrealistic P/VP values"))
  }

  # Check for vacancia > 100%
  invalid_vacancia <- sum(data$vacancia > 1, na.rm = TRUE)
  if (invalid_vacancia > 0) {
    issues <- c(issues, glue("{invalid_vacancia} vacância > 100%"))
  }

  issues
}

#' Validate Generic Data Quality
#'
#' @keywords internal
validate_generic_quality <- function(data, data_type, logger) {
  issues <- character(0)

  # Check for empty data
  if (nrow(data) == 0) {
    issues <- c(issues, "Data is empty (0 rows)")
    return(issues)
  }

  # Check for all NA columns
  all_na_cols <- names(data)[sapply(data, function(col) all(is.na(col)))]
  if (length(all_na_cols) > 0) {
    issues <- c(issues, glue("Columns with all NA: {paste(all_na_cols, collapse=', ')}"))
  }

  # Check for duplicate rows
  dup_count <- nrow(data) - nrow(distinct(data))
  if (dup_count > 0) {
    issues <- c(issues, glue("{dup_count} duplicate rows"))
  }

  # Check for high NA percentage (>50%)
  na_pct <- sapply(data, function(col) mean(is.na(col)))
  high_na_cols <- names(na_pct)[na_pct > 0.5]
  if (length(high_na_cols) > 0) {
    issues <- c(issues, glue("High NA % (>50%): {paste(high_na_cols, collapse=', ')}"))
  }

  issues
}

#' Check for Outliers
#'
#' Detects outliers using IQR method.
#'
#' @param data Data frame
#' @param column Column name
#' @param threshold IQR multiplier (default 3)
#' @param logger Logger instance
#' @return Indices of outliers
#' @export
detect_outliers <- function(data, column, threshold = 3, logger = NULL) {
  values <- data[[column]]
  values <- values[!is.na(values)]

  if (length(values) < 4) {
    return(integer(0))
  }

  Q1 <- quantile(values, 0.25)
  Q3 <- quantile(values, 0.75)
  IQR <- Q3 - Q1

  lower_bound <- Q1 - threshold * IQR
  upper_bound <- Q3 + threshold * IQR

  outliers <- which(data[[column]] < lower_bound | data[[column]] > upper_bound)

  if (!is.null(logger) && length(outliers) > 0) {
    logger$warn(glue("Found {length(outliers)} outliers in column '{column}'"))
  }

  outliers
}

#' Coalesce NULL Helper
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
