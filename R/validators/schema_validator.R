# schema_validator.R
# Validação de schemas de arquivos RDS
# Garante compatibilidade com estruturas esperadas

library(dplyr)
library(glue)

#' Define Expected Schemas
#'
#' @return List of schema definitions
#' @export
get_expected_schemas <- function() {
  list(
    income = list(
      ticker = "character",
      rendimento = "numeric",
      data_base = "Date",
      data_pagamento = "Date",
      cota_base = "numeric",
      dy = "numeric"
    ),
    quotations = list(
      ticker = "character",
      price = "numeric",
      date = "POSIXct"
    ),
    portfolio = list(
      date = "POSIXct",
      ticker = "character",
      volume = "numeric",
      price = "numeric",
      taxes = "numeric",
      value = "numeric",
      portfolio = "character"
    ),
    fii_indicators = list(
      ticker = "character",
      collected_at = "POSIXct",
      valor_atual = "numeric",
      min_52sem = "numeric",
      max_52sem = "numeric",
      dividend_yield = "numeric",
      valorizacao_12m = "numeric",
      p_vp = "numeric",
      valor_patrimonial = "numeric",
      vacancia = "numeric",
      valor_caixa = "numeric",
      liquidez = "numeric",
      numero_cotistas = "integer"
    )
  )
}

#' Validate Data Schema
#'
#' @param data Data frame to validate
#' @param schema_name Name of expected schema
#' @param strict If TRUE, fail on extra columns
#' @param logger Logger instance
#' @return List with validation result
#' @export
validate_schema <- function(data, schema_name, strict = FALSE, logger = NULL) {
  schemas <- get_expected_schemas()
  expected_schema <- schemas[[schema_name]]

  if (is.null(expected_schema)) {
    msg <- glue("Unknown schema: {schema_name}")
    if (!is.null(logger)) logger$error(msg)
    return(list(valid = FALSE, errors = msg))
  }

  errors <- character(0)

  # Check if data.frame
  if (!is.data.frame(data)) {
    errors <- c(errors, "Data is not a data frame")
    return(list(valid = FALSE, errors = errors))
  }

  # Check required columns
  missing_cols <- setdiff(names(expected_schema), names(data))
  if (length(missing_cols) > 0) {
    errors <- c(errors, glue("Missing columns: {paste(missing_cols, collapse=', ')}"))
  }

  # Check extra columns (if strict)
  if (strict) {
    extra_cols <- setdiff(names(data), names(expected_schema))
    if (length(extra_cols) > 0) {
      errors <- c(errors, glue("Extra columns: {paste(extra_cols, collapse=', ')}"))
    }
  }

  # Check column types
  for (col_name in names(expected_schema)) {
    if (col_name %in% names(data)) {
      expected_type <- expected_schema[[col_name]]
      actual_type <- class(data[[col_name]])[1]

      type_match <- check_type_compatibility(actual_type, expected_type)

      if (!type_match) {
        errors <- c(errors, glue("Column '{col_name}': expected {expected_type}, got {actual_type}"))
      }
    }
  }

  valid <- length(errors) == 0

  if (!is.null(logger)) {
    if (valid) {
      logger$debug(glue("Schema validation passed: {schema_name}"))
    } else {
      logger$error(glue("Schema validation failed: {schema_name}"))
      for (error in errors) {
        logger$error(glue("  - {error}"))
      }
    }
  }

  list(
    valid = valid,
    errors = errors,
    schema_name = schema_name
  )
}

#' Check Type Compatibility
#'
#' @keywords internal
check_type_compatibility <- function(actual_type, expected_type) {
  # Exact match
  if (actual_type == expected_type) return(TRUE)

  # Numeric types
  if (expected_type == "numeric" && actual_type %in% c("numeric", "integer", "double")) {
    return(TRUE)
  }

  if (expected_type == "integer" && actual_type %in% c("integer", "numeric")) {
    return(TRUE)
  }

  # Date/time types
  if (expected_type == "Date" && actual_type == "Date") {
    return(TRUE)
  }

  if (expected_type == "POSIXct" && actual_type %in% c("POSIXct", "POSIXt")) {
    return(TRUE)
  }

  # Character
  if (expected_type == "character" && actual_type == "character") {
    return(TRUE)
  }

  # Logical
  if (expected_type == "logical" && actual_type == "logical") {
    return(TRUE)
  }

  FALSE
}

#' Validate All RDS Files
#'
#' @param data_dir Directory with RDS files
#' @param logger Logger instance
#' @return List of validation results
#' @export
validate_all_rds <- function(data_dir = "data", logger = NULL) {
  if (!is.null(logger)) {
    logger$info("Validating all RDS files...")
  }

  results <- list()

  # Map files to schemas
  file_schema_map <- list(
    "income.rds" = "income",
    "quotations.rds" = "quotations",
    "portfolio.rds" = "portfolio",
    "fii_indicators.rds" = "fii_indicators"
  )

  for (filename in names(file_schema_map)) {
    filepath <- file.path(data_dir, filename)

    if (!file.exists(filepath)) {
      if (!is.null(logger)) {
        logger$debug(glue("File not found: {filename} (skipping)"))
      }
      next
    }

    schema_name <- file_schema_map[[filename]]

    tryCatch({
      data <- readRDS(filepath)
      validation <- validate_schema(data, schema_name, strict = FALSE, logger = logger)
      results[[filename]] <- validation
    },
    error = function(e) {
      if (!is.null(logger)) {
        logger$error(glue("Failed to validate {filename}: {e$message}"))
      }
      results[[filename]] <- list(
        valid = FALSE,
        errors = e$message,
        schema_name = schema_name
      )
    })
  }

  # Summary
  if (!is.null(logger)) {
    total <- length(results)
    valid_count <- sum(sapply(results, function(r) r$valid))
    logger$info(glue("Validation summary: {valid_count}/{total} files valid"))
  }

  results
}

#' Auto-Fix Schema Issues
#'
#' Attempts to automatically fix common schema issues.
#'
#' @param data Data frame
#' @param schema_name Schema name
#' @param logger Logger instance
#' @return Fixed data frame
#' @export
auto_fix_schema <- function(data, schema_name, logger = NULL) {
  schemas <- get_expected_schemas()
  expected_schema <- schemas[[schema_name]]

  if (is.null(expected_schema)) {
    return(data)
  }

  if (!is.null(logger)) {
    logger$info(glue("Attempting auto-fix for {schema_name}..."))
  }

  fixed_data <- data

  # Fix column types
  for (col_name in names(expected_schema)) {
    if (col_name %in% names(fixed_data)) {
      expected_type <- expected_schema[[col_name]]
      actual_type <- class(fixed_data[[col_name]])[1]

      if (actual_type != expected_type) {
        fixed_data <- tryCatch({
          if (expected_type == "numeric") {
            fixed_data[[col_name]] <- as.numeric(fixed_data[[col_name]])
          } else if (expected_type == "integer") {
            fixed_data[[col_name]] <- as.integer(fixed_data[[col_name]])
          } else if (expected_type == "character") {
            fixed_data[[col_name]] <- as.character(fixed_data[[col_name]])
          } else if (expected_type == "Date") {
            fixed_data[[col_name]] <- as.Date(fixed_data[[col_name]])
          } else if (expected_type == "POSIXct") {
            fixed_data[[col_name]] <- as.POSIXct(fixed_data[[col_name]])
          }

          if (!is.null(logger)) {
            logger$info(glue("Fixed column '{col_name}': {actual_type} → {expected_type}"))
          }

          fixed_data
        },
        error = function(e) {
          if (!is.null(logger)) {
            logger$warn(glue("Could not fix column '{col_name}': {e$message}"))
          }
          fixed_data
        })
      }
    }
  }

  # Add missing columns with NA
  missing_cols <- setdiff(names(expected_schema), names(fixed_data))
  for (col_name in missing_cols) {
    expected_type <- expected_schema[[col_name]]

    fixed_data[[col_name]] <- if (expected_type == "numeric") {
      NA_real_
    } else if (expected_type == "integer") {
      NA_integer_
    } else if (expected_type == "character") {
      NA_character_
    } else if (expected_type == "Date") {
      as.Date(NA)
    } else if (expected_type == "POSIXct") {
      as.POSIXct(NA)
    } else {
      NA
    }

    if (!is.null(logger)) {
      logger$info(glue("Added missing column '{col_name}' with NA"))
    }
  }

  # Reorder columns to match expected schema
  fixed_data <- fixed_data[, c(names(expected_schema), setdiff(names(fixed_data), names(expected_schema)))]

  fixed_data
}
