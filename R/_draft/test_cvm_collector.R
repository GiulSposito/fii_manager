# test_cvm_collector.R
# Test script for CVM collector implementation
# Validates that the collector works correctly with real portfolio data

library(dplyr)
library(glue)

# Source dependencies
source("R/import/fii_cvm_data.R")
source("R/utils/logging.R")

# =============================================================================
# Configuration
# =============================================================================

config <- list(
  base_url = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/",
  cache_dir = "data/.cache/cvm",
  cache_ttl_days = 30,
  data = list(
    portfolio_file = "data/portfolio.rds"
  ),
  output = "fii_cvm.rds"
)

# =============================================================================
# Setup Logger
# =============================================================================

logger <- create_logger(
  level = "DEBUG",
  format = "simple",
  console_enabled = TRUE,
  file_enabled = FALSE,
  context = "test_cvm"
)

# =============================================================================
# Test Functions
# =============================================================================

test_cnpj_mapping <- function() {
  logger$info("=" %R% 60)
  logger$info("TEST 1: CNPJ Mapping")
  logger$info("=" %R% 60)

  mapping <- build_cnpj_ticker_mapping(logger)

  if (nrow(mapping) == 0) {
    logger$error("FAILED: No mappings found")
    return(FALSE)
  }

  logger$info(glue("SUCCESS: Found {nrow(mapping)} ticker-CNPJ mappings"))
  logger$info("Sample mappings:")
  print(head(mapping, 10))
  logger$info("")

  TRUE
}

test_download_and_parse <- function() {
  logger$info("=" %R% 60)
  logger$info("TEST 2: Download and Parse CVM Data")
  logger$info("=" %R% 60)

  year <- lubridate::year(lubridate::today())

  cvm_data <- fetch_cvm_monthly_data(
    year = year,
    base_url = config$base_url,
    cache_dir = config$cache_dir,
    cache_ttl_days = config$cache_ttl_days,
    logger = logger
  )

  if (is.null(cvm_data) || nrow(cvm_data) == 0) {
    logger$error("FAILED: No data downloaded or parsed")
    return(FALSE)
  }

  logger$info(glue("SUCCESS: Downloaded and parsed {nrow(cvm_data)} rows"))
  logger$info(glue("Columns: {ncol(cvm_data)}"))
  logger$info("First few column names:")
  print(head(names(cvm_data), 20))
  logger$info("")

  TRUE
}

test_extract_indicators <- function() {
  logger$info("=" %R% 60)
  logger$info("TEST 3: Extract Indicators")
  logger$info("=" %R% 60)

  # Get mapping
  mapping <- build_cnpj_ticker_mapping(logger)

  if (nrow(mapping) == 0) {
    logger$error("FAILED: No mapping available")
    return(FALSE)
  }

  # Download CVM data
  year <- lubridate::year(lubridate::today())
  cvm_data <- fetch_cvm_monthly_data(
    year = year,
    base_url = config$base_url,
    cache_dir = config$cache_dir,
    cache_ttl_days = config$cache_ttl_days,
    logger = logger
  )

  if (is.null(cvm_data) || nrow(cvm_data) == 0) {
    logger$error("FAILED: No CVM data available")
    return(FALSE)
  }

  # Extract indicators
  indicators <- extract_fii_indicators(
    cvm_data = cvm_data,
    mapping = mapping,
    logger = logger
  )

  if (nrow(indicators) == 0) {
    logger$warn("WARNING: No indicators extracted (might be expected if no portfolio tickers in CVM data)")
    return(TRUE)  # Not a failure - portfolio might not have CNPJs in mapping
  }

  logger$info(glue("SUCCESS: Extracted {nrow(indicators)} indicator records"))
  logger$info(glue("Unique tickers: {n_distinct(indicators$ticker)}"))
  logger$info(glue("Date range: {min(indicators$data_competencia)} to {max(indicators$data_competencia)}"))

  logger$info("\nSample data:")
  print(head(indicators, 5))

  logger$info("\nColumn summary:")
  print(glimpse(indicators))

  logger$info("")

  TRUE
}

test_full_collector <- function() {
  logger$info("=" %R% 60)
  logger$info("TEST 4: Full Collector Integration")
  logger$info("=" %R% 60)

  # Create collector
  collector <- create_cvm_collector(config, logger)

  logger$info(glue("Collector name: {collector$name}"))

  # Run collection
  result <- collector$collect()

  if (!result$success) {
    logger$error(glue("FAILED: {result$error}"))
    return(FALSE)
  }

  logger$info("SUCCESS: Collector ran successfully")
  logger$info("\nMetadata:")
  print(result$metadata)

  logger$info("\nData summary:")
  if (!is.null(result$data) && nrow(result$data) > 0) {
    logger$info(glue("Rows: {nrow(result$data)}"))
    logger$info(glue("Tickers: {n_distinct(result$data$ticker)}"))
    logger$info(glue("Date range: {min(result$data$data_competencia)} to {max(result$data$data_competencia)}"))

    logger$info("\nSample records:")
    print(head(result$data, 3))
  } else {
    logger$warn("No data collected (might be expected if no portfolio tickers have CNPJ mapping)")
  }

  logger$info("")

  TRUE
}

test_get_history <- function() {
  logger$info("=" %R% 60)
  logger$info("TEST 5: Get FII History")
  logger$info("=" %R% 60)

  # Check if data file exists
  if (!file.exists("data/fii_cvm.rds")) {
    logger$warn("SKIPPED: fii_cvm.rds not found (run collector first)")
    return(TRUE)
  }

  # Load data to find a ticker to test
  cvm_data <- readRDS("data/fii_cvm.rds")

  if (nrow(cvm_data) == 0) {
    logger$warn("SKIPPED: No data in fii_cvm.rds")
    return(TRUE)
  }

  test_ticker <- cvm_data$ticker[1]

  logger$info(glue("Testing get_fii_cvm_history() with ticker: {test_ticker}"))

  history <- get_fii_cvm_history(test_ticker, months = 12)

  logger$info(glue("Retrieved {nrow(history)} months of history"))

  if (nrow(history) > 0) {
    logger$info("Sample history:")
    print(head(history, 3))
  }

  logger$info("")

  TRUE
}

# =============================================================================
# Run All Tests
# =============================================================================

run_all_tests <- function() {
  logger$info("")
  logger$info("=" %R% 60)
  logger$info("CVM COLLECTOR TEST SUITE")
  logger$info("=" %R% 60)
  logger$info("")

  tests <- list(
    "CNPJ Mapping" = test_cnpj_mapping,
    "Download & Parse" = test_download_and_parse,
    "Extract Indicators" = test_extract_indicators,
    "Full Collector" = test_full_collector,
    "Get History" = test_get_history
  )

  results <- list()

  for (test_name in names(tests)) {
    test_fn <- tests[[test_name]]

    tryCatch({
      passed <- test_fn()
      results[[test_name]] <- passed
    }, error = function(e) {
      logger$error(glue("TEST ERROR ({test_name}): {e$message}"))
      results[[test_name]] <- FALSE
    })
  }

  # Summary
  logger$info("=" %R% 60)
  logger$info("TEST SUMMARY")
  logger$info("=" %R% 60)

  passed_count <- sum(unlist(results))
  total_count <- length(results)

  for (test_name in names(results)) {
    status <- if (results[[test_name]]) "PASS" else "FAIL"
    logger$info(glue("{test_name}: {status}"))
  }

  logger$info("")
  logger$info(glue("Total: {passed_count}/{total_count} tests passed"))
  logger$info("=" %R% 60)

  if (passed_count == total_count) {
    logger$info("ALL TESTS PASSED!")
  } else {
    logger$error(glue("{total_count - passed_count} tests failed"))
  }

  invisible(results)
}

# String repeat helper
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}

# =============================================================================
# Execute Tests (if run as script)
# =============================================================================

if (!interactive()) {
  results <- run_all_tests()

  # Exit with appropriate code
  if (all(unlist(results))) {
    quit(status = 0)
  } else {
    quit(status = 1)
  }
}

# For interactive testing:
# results <- run_all_tests()
# View individual tests:
# test_cnpj_mapping()
# test_full_collector()
