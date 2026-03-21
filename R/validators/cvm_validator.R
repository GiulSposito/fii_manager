# cvm_validator.R
# Validação de dados CVM (Comissão de Valores Mobiliários)
# Valida estrutura, ranges, consistência e completude de dados fundamentalistas FII

library(dplyr)
library(lubridate)
library(glue)

#' Validate CVM Schema
#'
#' Validates that CVM data has expected columns and types.
#'
#' @param cvm_data Data frame with CVM data
#' @param logger Logger instance (optional)
#' @return List with validation result (valid, errors, warnings)
#' @export
validate_cvm_schema <- function(cvm_data, logger = NULL) {
  if (!is.null(logger)) {
    logger$debug("Validating CVM schema...")
  }

  errors <- character(0)
  warnings <- character(0)

  # Check if data.frame
  if (!is.data.frame(cvm_data)) {
    errors <- c(errors, "Data is not a data frame")
    return(list(valid = FALSE, errors = errors, warnings = warnings))
  }

  # Expected columns
  expected_cols <- c(
    "ticker",
    "data_competencia",
    "patrimonio_liquido",
    "valor_patrimonial_cota",
    "dividend_yield",
    "rentabilidade_mensal",
    "numero_cotistas",
    "segmento",
    "tx_administracao"
  )

  # Check required columns
  missing_cols <- setdiff(expected_cols, names(cvm_data))
  if (length(missing_cols) > 0) {
    errors <- c(errors, glue("Missing columns: {paste(missing_cols, collapse=', ')}"))
  }

  # If columns are missing, we can't validate types
  if (length(missing_cols) > 0) {
    valid <- FALSE
    if (!is.null(logger)) {
      logger$error(glue("CVM schema validation failed: missing {length(missing_cols)} columns"))
    }
    return(list(valid = valid, errors = errors, warnings = warnings))
  }

  # Check column types
  type_checks <- list(
    ticker = "character",
    data_competencia = c("Date", "POSIXct", "POSIXt"),
    patrimonio_liquido = c("numeric", "integer", "double"),
    valor_patrimonial_cota = c("numeric", "integer", "double"),
    dividend_yield = c("numeric", "integer", "double"),
    rentabilidade_mensal = c("numeric", "integer", "double"),
    numero_cotistas = c("numeric", "integer", "double"),
    segmento = "character",
    tx_administracao = c("numeric", "integer", "double")
  )

  for (col in names(type_checks)) {
    if (col %in% names(cvm_data)) {
      actual_type <- class(cvm_data[[col]])[1]
      expected_types <- type_checks[[col]]

      if (!actual_type %in% expected_types) {
        errors <- c(errors, glue("Column '{col}': expected {paste(expected_types, collapse='|')}, got {actual_type}"))
      }
    }
  }

  # Optional columns (warn if missing)
  optional_cols <- c("nome_fundo", "tx_performance")
  missing_optional <- setdiff(optional_cols, names(cvm_data))
  if (length(missing_optional) > 0) {
    warnings <- c(warnings, glue("Optional columns missing: {paste(missing_optional, collapse=', ')}"))
  }

  valid <- length(errors) == 0

  if (!is.null(logger)) {
    if (valid) {
      logger$debug("CVM schema validation passed")
    } else {
      logger$error(glue("CVM schema validation failed: {length(errors)} errors"))
      for (error in errors) {
        logger$error(glue("  - {error}"))
      }
    }
  }

  list(
    valid = valid,
    errors = errors,
    warnings = warnings
  )
}

#' Validate CVM Ranges
#'
#' Validates that CVM data values are within expected ranges.
#'
#' @param cvm_data Data frame with CVM data
#' @param logger Logger instance (optional)
#' @return List with validation issues
#' @export
validate_cvm_ranges <- function(cvm_data, logger = NULL) {
  if (!is.null(logger)) {
    logger$debug("Validating CVM ranges...")
  }

  issues <- character(0)

  if (!is.data.frame(cvm_data) || nrow(cvm_data) == 0) {
    issues <- c(issues, "Data is empty or invalid")
    return(list(valid = FALSE, issues = issues))
  }

  # Check patrimonio_liquido > 0
  if ("patrimonio_liquido" %in% names(cvm_data)) {
    invalid_pl <- sum(cvm_data$patrimonio_liquido <= 0, na.rm = TRUE)
    if (invalid_pl > 0) {
      issues <- c(issues, glue("{invalid_pl} records with patrimonio_liquido <= 0"))
    }
  }

  # Check valor_patrimonial_cota > 0 (VP/cota)
  if ("valor_patrimonial_cota" %in% names(cvm_data)) {
    invalid_vp <- sum(cvm_data$valor_patrimonial_cota <= 0, na.rm = TRUE)
    if (invalid_vp > 0) {
      issues <- c(issues, glue("{invalid_vp} records with valor_patrimonial_cota <= 0"))
    }
  }

  # Check dividend_yield between -100% and 100% (can be negative in bad months)
  # DY is stored as decimal (e.g., 0.01 = 1%)
  if ("dividend_yield" %in% names(cvm_data)) {
    invalid_dy <- sum(cvm_data$dividend_yield < -1 | cvm_data$dividend_yield > 1, na.rm = TRUE)
    if (invalid_dy > 0) {
      issues <- c(issues, glue("{invalid_dy} records with dividend_yield outside [-100%, 100%]"))
    }
  }

  # Check rentabilidade between -50% and 50%
  if ("rentabilidade_mensal" %in% names(cvm_data)) {
    invalid_rent <- sum(cvm_data$rentabilidade_mensal < -0.5 | cvm_data$rentabilidade_mensal > 0.5, na.rm = TRUE)
    if (invalid_rent > 0) {
      issues <- c(issues, glue("{invalid_rent} records with rentabilidade_mensal outside [-50%, 50%]"))
    }
  }

  # Check numero_cotistas > 0
  if ("numero_cotistas" %in% names(cvm_data)) {
    invalid_cotistas <- sum(cvm_data$numero_cotistas <= 0, na.rm = TRUE)
    if (invalid_cotistas > 0) {
      issues <- c(issues, glue("{invalid_cotistas} records with numero_cotistas <= 0"))
    }
  }

  # Check tx_administracao >= 0 and < 5% (annual fee)
  if ("tx_administracao" %in% names(cvm_data)) {
    invalid_tx <- sum(cvm_data$tx_administracao < 0 | cvm_data$tx_administracao >= 0.05, na.rm = TRUE)
    if (invalid_tx > 0) {
      issues <- c(issues, glue("{invalid_tx} records with tx_administracao outside [0%, 5%)"))
    }
  }

  # Check data_competencia is not too old (e.g., > 10 years ago)
  if ("data_competencia" %in% names(cvm_data)) {
    min_date <- as.Date("2010-01-01")
    old_dates <- sum(as.Date(cvm_data$data_competencia) < min_date, na.rm = TRUE)
    if (old_dates > 0) {
      issues <- c(issues, glue("{old_dates} records with data_competencia before {min_date}"))
    }

    # Check for future dates (more than 3 months ahead)
    max_future <- Sys.Date() + months(3)
    future_dates <- sum(as.Date(cvm_data$data_competencia) > max_future, na.rm = TRUE)
    if (future_dates > 0) {
      issues <- c(issues, glue("{future_dates} records with data_competencia more than 3 months in future"))
    }
  }

  valid <- length(issues) == 0

  if (!is.null(logger)) {
    if (valid) {
      logger$debug("CVM ranges validation passed")
    } else {
      logger$warn(glue("CVM ranges validation found {length(issues)} issues"))
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
    issues = issues
  )
}

#' Validate CVM Consistency
#'
#' Validates consistency of CVM data with other sources.
#'
#' @param cvm_data Data frame with CVM data
#' @param other_sources List with other data sources (fiis, quotations)
#' @param logger Logger instance (optional)
#' @return List with consistency report
#' @export
validate_cvm_consistency <- function(cvm_data, other_sources = list(), logger = NULL) {
  if (!is.null(logger)) {
    logger$debug("Validating CVM consistency...")
  }

  issues <- list()

  if (!is.data.frame(cvm_data) || nrow(cvm_data) == 0) {
    issues$empty_data <- "CVM data is empty or invalid"
    return(list(valid = FALSE, issues = issues))
  }

  cvm_tickers <- unique(cvm_data$ticker)

  # Check 1: Validate tickers against fiis.rds
  if (!is.null(other_sources$fiis)) {
    fiis_tickers <- unique(other_sources$fiis$ticker)

    # CVM tickers should be subset of fiis tickers
    unknown_tickers <- setdiff(cvm_tickers, fiis_tickers)
    if (length(unknown_tickers) > 0) {
      issues$unknown_tickers <- unknown_tickers
      if (!is.null(logger)) {
        logger$warn(glue("{length(unknown_tickers)} CVM tickers not found in fiis.rds"))
      }
    }

    # Expected tickers missing in CVM
    missing_tickers <- setdiff(fiis_tickers, cvm_tickers)
    if (length(missing_tickers) > 0) {
      issues$missing_tickers <- missing_tickers
      if (!is.null(logger)) {
        logger$info(glue("{length(missing_tickers)} fiis.rds tickers not found in CVM data"))
      }
    }
  }

  # Check 2: Detect duplicates (ticker + data_competencia)
  if ("ticker" %in% names(cvm_data) && "data_competencia" %in% names(cvm_data)) {
    duplicates <- cvm_data %>%
      group_by(ticker, data_competencia) %>%
      filter(n() > 1) %>%
      ungroup()

    if (nrow(duplicates) > 0) {
      issues$duplicates <- nrow(duplicates)
      if (!is.null(logger)) {
        logger$warn(glue("{nrow(duplicates)} duplicate records (ticker + data_competencia)"))
      }
    }
  }

  # Check 3: Validate chronological order per ticker
  if ("ticker" %in% names(cvm_data) && "data_competencia" %in% names(cvm_data)) {
    non_chronological <- cvm_data %>%
      arrange(ticker, data_competencia) %>%
      group_by(ticker) %>%
      mutate(
        prev_date = lag(data_competencia),
        is_chronological = is.na(prev_date) | data_competencia >= prev_date
      ) %>%
      filter(!is_chronological) %>%
      nrow()

    if (non_chronological > 0) {
      issues$non_chronological <- non_chronological
      if (!is.null(logger)) {
        logger$warn(glue("{non_chronological} records out of chronological order"))
      }
    }
  }

  # Check 4: Cross-check VP/cota with quotations (price)
  if (!is.null(other_sources$quotations) &&
      "valor_patrimonial_cota" %in% names(cvm_data) &&
      "ticker" %in% names(cvm_data) &&
      "data_competencia" %in% names(cvm_data)) {

    quotations <- other_sources$quotations %>%
      mutate(date = as.Date(date)) %>%
      select(ticker, date, price)

    # Join CVM with quotations on ticker + date
    comparison <- cvm_data %>%
      filter(!is.na(valor_patrimonial_cota)) %>%
      left_join(
        quotations,
        by = c("ticker", "data_competencia" = "date")
      ) %>%
      filter(!is.na(price)) %>%
      mutate(
        pct_diff = abs(valor_patrimonial_cota - price) / price,
        large_diff = pct_diff > 0.20  # More than 20% difference
      )

    large_diffs <- sum(comparison$large_diff, na.rm = TRUE)
    if (large_diffs > 0) {
      issues$vp_price_mismatch <- large_diffs
      if (!is.null(logger)) {
        logger$warn(glue("{large_diffs} records with VP/cota vs price difference > 20%"))
      }
    }

    # Store comparison details
    if (large_diffs > 0) {
      issues$vp_price_details <- comparison %>%
        filter(large_diff) %>%
        select(ticker, data_competencia, valor_patrimonial_cota, price, pct_diff) %>%
        head(10)  # First 10 for reporting
    }
  }

  valid <- length(issues) == 0

  if (!is.null(logger)) {
    if (valid) {
      logger$debug("CVM consistency validation passed")
    } else {
      logger$warn(glue("CVM consistency validation found {length(issues)} issue types"))
    }
  }

  list(
    valid = valid,
    issues = issues
  )
}

#' Validate CVM Completeness
#'
#' Validates data completeness: missing tickers, temporal gaps, NA fields.
#'
#' @param cvm_data Data frame with CVM data
#' @param expected_tickers Character vector of expected tickers (optional)
#' @param logger Logger instance (optional)
#' @return List with completeness statistics
#' @export
validate_cvm_completeness <- function(cvm_data, expected_tickers = NULL, logger = NULL) {
  if (!is.null(logger)) {
    logger$debug("Validating CVM completeness...")
  }

  report <- list()

  if (!is.data.frame(cvm_data) || nrow(cvm_data) == 0) {
    report$empty <- TRUE
    report$completeness_pct <- 0
    return(report)
  }

  # Check 1: Missing expected tickers
  if (!is.null(expected_tickers)) {
    cvm_tickers <- unique(cvm_data$ticker)
    missing_tickers <- setdiff(expected_tickers, cvm_tickers)

    report$expected_tickers <- length(expected_tickers)
    report$found_tickers <- length(cvm_tickers)
    report$missing_tickers <- missing_tickers
    report$ticker_completeness_pct <- round(100 * length(cvm_tickers) / length(expected_tickers), 2)

    if (!is.null(logger)) {
      logger$info(glue("Ticker completeness: {report$found_tickers}/{report$expected_tickers} ({report$ticker_completeness_pct}%)"))
      if (length(missing_tickers) > 0) {
        logger$warn(glue("Missing tickers: {paste(head(missing_tickers, 10), collapse=', ')}"))
        if (length(missing_tickers) > 10) {
          logger$warn(glue("  ... and {length(missing_tickers) - 10} more"))
        }
      }
    }
  } else {
    report$found_tickers <- n_distinct(cvm_data$ticker)
  }

  # Check 2: Temporal gaps (missing months) per ticker
  if ("ticker" %in% names(cvm_data) && "data_competencia" %in% names(cvm_data)) {
    temporal_analysis <- cvm_data %>%
      mutate(data_competencia = as.Date(data_competencia)) %>%
      group_by(ticker) %>%
      summarise(
        min_date = min(data_competencia, na.rm = TRUE),
        max_date = max(data_competencia, na.rm = TRUE),
        n_months = n(),
        .groups = "drop"
      ) %>%
      mutate(
        expected_months = as.numeric(difftime(max_date, min_date, units = "days")) / 30,
        expected_months = ceiling(expected_months),
        gap_months = pmax(0, expected_months - n_months),
        completeness_pct = round(100 * n_months / pmax(1, expected_months), 2)
      )

    tickers_with_gaps <- sum(temporal_analysis$gap_months > 0)
    avg_completeness <- mean(temporal_analysis$completeness_pct, na.rm = TRUE)

    report$tickers_with_gaps <- tickers_with_gaps
    report$avg_temporal_completeness_pct <- round(avg_completeness, 2)
    report$temporal_details <- temporal_analysis

    if (!is.null(logger)) {
      logger$info(glue("Temporal completeness: {round(avg_completeness, 1)}% (avg across tickers)"))
      if (tickers_with_gaps > 0) {
        logger$warn(glue("{tickers_with_gaps} tickers have temporal gaps"))
      }
    }
  }

  # Check 3: Field completeness (% non-NA)
  field_completeness <- cvm_data %>%
    summarise(across(everything(), ~ round(100 * mean(!is.na(.)), 2))) %>%
    pivot_longer(everything(), names_to = "field", values_to = "completeness_pct")

  report$field_completeness <- field_completeness

  # Identify fields with low completeness (<80%)
  low_completeness_fields <- field_completeness %>%
    filter(completeness_pct < 80)

  if (nrow(low_completeness_fields) > 0) {
    report$low_completeness_fields <- low_completeness_fields

    if (!is.null(logger)) {
      logger$warn(glue("{nrow(low_completeness_fields)} fields with completeness < 80%"))
      for (i in 1:min(5, nrow(low_completeness_fields))) {
        field <- low_completeness_fields$field[i]
        pct <- low_completeness_fields$completeness_pct[i]
        logger$warn(glue("  - {field}: {pct}%"))
      }
    }
  }

  # Overall completeness score (average of all metrics)
  overall_scores <- c(
    if (!is.null(expected_tickers)) report$ticker_completeness_pct else 100,
    report$avg_temporal_completeness_pct %||% 100,
    mean(field_completeness$completeness_pct, na.rm = TRUE)
  )

  report$overall_completeness_pct <- round(mean(overall_scores, na.rm = TRUE), 2)

  if (!is.null(logger)) {
    logger$info(glue("Overall completeness: {report$overall_completeness_pct}%"))
  }

  report
}

#' Validate CVM All
#'
#' Executes all CVM validations and returns consolidated report.
#'
#' @param cvm_data Data frame with CVM data
#' @param other_sources List with other data sources (fiis, quotations)
#' @param expected_tickers Character vector of expected tickers (optional)
#' @param logger Logger instance (optional)
#' @return List with complete validation report
#' @export
validate_cvm_all <- function(cvm_data, other_sources = list(), expected_tickers = NULL, logger = NULL) {
  if (!is.null(logger)) {
    logger$info("Running complete CVM validation suite...")
  }

  start_time <- Sys.time()

  # Run all validations
  schema_result <- validate_cvm_schema(cvm_data, logger)
  ranges_result <- validate_cvm_ranges(cvm_data, logger)
  consistency_result <- validate_cvm_consistency(cvm_data, other_sources, logger)
  completeness_result <- validate_cvm_completeness(cvm_data, expected_tickers, logger)

  # Overall validity
  overall_valid <- schema_result$valid &&
                   ranges_result$valid &&
                   consistency_result$valid

  # Summary statistics
  summary_stats <- list(
    total_rows = nrow(cvm_data),
    total_tickers = n_distinct(cvm_data$ticker),
    date_range = if ("data_competencia" %in% names(cvm_data)) {
      list(
        min = min(as.Date(cvm_data$data_competencia), na.rm = TRUE),
        max = max(as.Date(cvm_data$data_competencia), na.rm = TRUE)
      )
    } else {
      NULL
    },
    completeness_pct = completeness_result$overall_completeness_pct,
    validation_duration_secs = as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  )

  # Compile report
  report <- list(
    schema = schema_result,
    ranges = ranges_result,
    consistency = consistency_result,
    completeness = completeness_result,
    overall_valid = overall_valid,
    summary = summary_stats
  )

  if (!is.null(logger)) {
    logger$info(glue("CVM validation completed in {round(summary_stats$validation_duration_secs, 2)}s"))
    logger$info(glue("Overall valid: {overall_valid}"))
    logger$info(glue("Summary: {summary_stats$total_rows} rows, {summary_stats$total_tickers} tickers, {summary_stats$completeness_pct}% complete"))
  }

  report
}

#' Coalesce NULL Helper
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
