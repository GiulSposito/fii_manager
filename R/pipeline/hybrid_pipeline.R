# hybrid_pipeline.R
# Orquestrador principal do pipeline híbrido de coleta de dados de FIIs
# Coordena execução de collectors por prioridade, gerencia fallbacks, e valida dados

library(yaml)
library(dplyr)
library(purrr)
library(glue)

# Carregar utilities
source("R/utils/logging.R")
source("R/utils/http_client.R")
source("R/utils/brazilian_parsers.R")
source("R/utils/persistence.R")

#' Run Hybrid Pipeline
#'
#' Executes the hybrid FII data collection pipeline.
#' Coordinates all collectors by priority, manages fallbacks, validates data.
#'
#' @param config_path Path to YAML configuration file
#' @param mode Execution mode: "incremental" or "full_refresh"
#' @param sources Character vector of sources to run (NULL = all enabled)
#' @return List with execution results
#' @export
hybrid_pipeline_run <- function(config_path = "config/pipeline_config.yaml",
                                 mode = NULL,
                                 sources = NULL) {

  # ===========================================================================
  # 1. SETUP
  # ===========================================================================

  cat("\n")
  cat("=" %R% 80, "\n")
  cat("HYBRID PIPELINE - FII Data Collection\n")
  cat("=" %R% 80, "\n\n")

  start_time <- Sys.time()

  # Load config
  config <- tryCatch({
    yaml::read_yaml(config_path)
  }, error = function(e) {
    stop(glue("Failed to load config from {config_path}: {e$message}"))
  })

  # Override mode if specified
  if (!is.null(mode)) {
    config$execution$mode <- mode
  }

  # Setup logger
  logger <- setup_logging(config, context = "hybrid_pipeline")
  logger$info("=" %R% 60)
  logger$info("Hybrid Pipeline Started")
  logger$info("=" %R% 60)
  logger$info(glue("Config: {config_path}"))
  logger$info(glue("Mode: {config$execution$mode}"))
  logger$info(glue("Cache: {config$execution$cache_enabled}"))
  logger$info(glue("Validation: {config$execution$validation_enabled}"))

  # ===========================================================================
  # 2. INITIALIZE COLLECTORS
  # ===========================================================================

  logger$info("Initializing collectors...")

  # Get enabled sources
  enabled_sources <- names(config$data_sources)[
    sapply(config$data_sources, function(s) s$enabled %||% TRUE)
  ]

  # Filter by sources parameter if provided
  if (!is.null(sources)) {
    enabled_sources <- intersect(enabled_sources, sources)
  }

  logger$info(glue("Enabled sources: {paste(enabled_sources, collapse=', ')}"))

  # Sort by priority
  sources_sorted <- enabled_sources[
    order(sapply(enabled_sources, function(s) {
      config$data_sources[[s]]$priority %||% 999
    }))
  ]

  logger$info(glue("Execution order: {paste(sources_sorted, collapse=' → ')}"))

  # ===========================================================================
  # 3. EXECUTE COLLECTORS
  # ===========================================================================

  logger$info("=" %R% 60)
  logger$info("Executing Collectors")
  logger$info("=" %R% 60)

  results <- list()

  for (source_name in sources_sorted) {
    source_config <- config$data_sources[[source_name]]

    logger$info("")
    logger$info(glue("[{source_name}] Starting..."))
    logger$set_context(source_name)

    collector_result <- execute_collector_with_fallback(
      source_name,
      source_config,
      config,
      logger
    )

    results[[source_name]] <- collector_result

    if (collector_result$success) {
      logger$info(glue("[{source_name}] ✓ Success ({collector_result$rows} rows, {collector_result$duration}s)"))
    } else {
      logger$error(glue("[{source_name}] ✗ Failed: {collector_result$error}"))

      # Stop if critical and failed
      if (source_config$critical %||% FALSE) {
        logger$error("Critical source failed - stopping pipeline")
        break
      }
    }

    logger$set_context("hybrid_pipeline")
  }

  # ===========================================================================
  # 4. VALIDATION
  # ===========================================================================

  if (config$execution$validation_enabled %||% TRUE) {
    logger$info("=" %R% 60)
    logger$info("Validating Data")
    logger$info("=" %R% 60)

    validation_results <- validate_pipeline_results(results, config, logger)
    results$validation <- validation_results
  }

  # ===========================================================================
  # 5. SUMMARY
  # ===========================================================================

  end_time <- Sys.time()
  total_duration <- as.numeric(difftime(end_time, start_time, units = "secs"))

  logger$info("=" %R% 60)
  logger$info("Pipeline Execution Summary")
  logger$info("=" %R% 60)

  total <- length(results) - (if ("validation" %in% names(results)) 1 else 0)
  success <- sum(sapply(results[sources_sorted], function(r) r$success %||% FALSE))
  failed <- total - success

  logger$info(glue("Total sources: {total}"))
  logger$info(glue("Successful: {success}"))
  logger$info(glue("Failed: {failed}"))
  logger$info(glue("Duration: {round(total_duration, 1)}s"))

  if (failed > 0) {
    logger$warn("Failed sources:")
    for (name in sources_sorted) {
      if (!results[[name]]$success) {
        logger$warn(glue("  - {name}: {results[[name]]$error}"))
      }
    }
  }

  logger$info("=" %R% 60)
  logger$info("Pipeline Completed")
  logger$info("=" %R% 60)
  cat("\n")

  # Return results
  results$summary <- list(
    total = total,
    success = success,
    failed = failed,
    duration = total_duration,
    start_time = start_time,
    end_time = end_time
  )

  invisible(results)
}

#' Execute Collector with Fallback
#'
#' @keywords internal
execute_collector_with_fallback <- function(source_name, source_config, config, logger) {
  start_time <- Sys.time()

  result <- tryCatch({
    # Load and execute collector
    collector_file <- get_collector_file(source_name)

    if (!file.exists(collector_file)) {
      stop(glue("Collector file not found: {collector_file}"))
    }

    source(collector_file, local = TRUE)

    # Create collector instance
    collector <- create_collector(source_name, source_config, config, logger)

    # Execute collection
    data <- log_execution_time(
      logger,
      function() collector$collect(),
      glue("Collecting {source_name}")
    )

    # Save data
    if (!is.null(data) && nrow(data) > 0) {
      output_path <- file.path("data", source_config$output)

      save_incremental(
        data,
        output_path,
        dedup_columns = get_dedup_columns(source_name),
        logger = logger
      )

      end_time <- Sys.time()
      duration <- as.numeric(difftime(end_time, start_time, units = "secs"))

      list(
        success = TRUE,
        source = source_name,
        rows = nrow(data),
        output = output_path,
        duration = round(duration, 2),
        timestamp = Sys.time()
      )
    } else {
      stop("Collector returned empty data")
    }
  },
  error = function(e) {
    end_time <- Sys.time()
    duration <- as.numeric(difftime(end_time, start_time, units = "secs"))

    logger$error(glue("Collection failed: {e$message}"))

    # Try fallback if configured
    fallback_result <- try_fallback(source_name, config, logger)

    if (!is.null(fallback_result) && fallback_result$success) {
      return(fallback_result)
    }

    list(
      success = FALSE,
      source = source_name,
      error = e$message,
      duration = round(duration, 2),
      timestamp = Sys.time()
    )
  })

  result
}

#' Get Collector File Path
#'
#' @keywords internal
get_collector_file <- function(source_name) {
  # Map source names to collector files
  collector_map <- list(
    statusinvest_income = "R/collectors/statusinvest_income_collector.R",
    statusinvest_indicators = "R/collectors/statusinvest_indicators_collector.R",
    fiiscom_lupa = "R/collectors/fiiscom_lupa_collector.R",
    portfolio_googlesheets = "R/collectors/portfolio_collector.R",
    yahoo_prices = "R/collectors/yahoo_prices_collector.R"
  )

  collector_map[[source_name]] %||% glue("R/collectors/{source_name}_collector.R")
}

#' Create Collector Instance
#'
#' @keywords internal
create_collector <- function(source_name, source_config, config, logger) {
  # Collector factory - calls create_<name>_collector() function
  collector_fn <- get(glue("create_{source_name}_collector"), mode = "function")
  collector_fn(source_config, config, logger)
}

#' Get Deduplication Columns
#'
#' @keywords internal
get_dedup_columns <- function(source_name) {
  dedup_map <- list(
    statusinvest_income = c("ticker", "data_base"),
    statusinvest_indicators = c("ticker", "collected_at"),
    fiiscom_lupa = c("ticker"),
    portfolio_googlesheets = c("date", "ticker", "portfolio"),
    yahoo_prices = c("ticker", "date")
  )

  dedup_map[[source_name]]
}

#' Try Fallback Source
#'
#' @keywords internal
try_fallback <- function(source_name, config, logger) {
  # Check if fallback is configured
  fallback_config <- config$fallback[[source_name]]

  if (is.null(fallback_config)) {
    return(NULL)
  }

  fallback_source <- fallback_config$fallback

  if (is.null(fallback_source)) {
    return(NULL)
  }

  logger$info(glue("Trying fallback: {fallback_source}"))

  # Execute fallback
  fallback_source_config <- config$data_sources[[fallback_source]]

  if (is.null(fallback_source_config)) {
    logger$warn(glue("Fallback source not configured: {fallback_source}"))
    return(NULL)
  }

  execute_collector_with_fallback(
    fallback_source,
    fallback_source_config,
    config,
    logger
  )
}

#' Validate Pipeline Results
#'
#' @keywords internal
validate_pipeline_results <- function(results, config, logger) {
  validation_results <- list()

  # Basic validation: check if critical sources succeeded
  for (source_name in names(results)) {
    if (source_name == "validation") next

    result <- results[[source_name]]
    source_config <- config$data_sources[[source_name]]

    if (source_config$critical %||% FALSE) {
      if (!result$success) {
        validation_results$critical_failures <- c(
          validation_results$critical_failures,
          source_name
        )
      }
    }
  }

  # Cross-source validation (if enabled)
  if (config$validation$consistency$cross_source %||% FALSE) {
    logger$info("Running cross-source validation...")

    # Load data for validation
    income_path <- "data/income.rds"
    portfolio_path <- "data/portfolio.rds"

    if (file.exists(income_path) && file.exists(portfolio_path)) {
      income <- readRDS(income_path)
      portfolio <- readRDS(portfolio_path)

      # Check: all income tickers are in portfolio
      income_tickers <- unique(income$ticker)
      portfolio_tickers <- unique(portfolio$ticker)
      missing_in_portfolio <- setdiff(income_tickers, portfolio_tickers)

      if (length(missing_in_portfolio) > 0) {
        logger$warn(glue("Tickers in income but not in portfolio: {paste(missing_in_portfolio, collapse=', ')}"))
        validation_results$inconsistencies$missing_in_portfolio <- missing_in_portfolio
      }
    }
  }

  validation_results$passed <- length(validation_results$critical_failures %||% character(0)) == 0

  if (validation_results$passed) {
    logger$info("✓ Validation passed")
  } else {
    logger$error("✗ Validation failed")
  }

  validation_results
}

#' Helper: String Repeat
#' @keywords internal
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}

#' Helper: Coalesce NULL
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
