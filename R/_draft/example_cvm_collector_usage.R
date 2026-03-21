# example_cvm_collector_usage.R
# Examples of how to use the CVM collector in different scenarios

library(dplyr)
library(glue)

source("R/import/fii_cvm_data.R")
source("R/utils/logging.R")

# =============================================================================
# Example 1: Basic Collection with Default Config
# =============================================================================

example_basic_collection <- function() {
  cat("\n=== Example 1: Basic Collection ===\n\n")

  # Setup logger
  logger <- create_logger(level = "INFO", console_enabled = TRUE, file_enabled = FALSE)

  # Configuration
  config <- list(
    base_url = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/",
    cache_dir = "data/.cache/cvm",
    cache_ttl_days = 30,
    data = list(
      portfolio_file = "data/portfolio.rds"
    ),
    output = "fii_cvm.rds"
  )

  # Create and run collector
  collector <- create_cvm_collector(config, logger)
  result <- collector$collect()

  # Check result
  if (result$success) {
    cat("✓ Collection successful!\n")
    cat(glue("  - {result$metadata$tickers_success} tickers collected\n"))
    cat(glue("  - {result$metadata$rows} total rows\n"))
    cat(glue("  - Duration: {round(result$metadata$duration_secs, 2)}s\n"))
  } else {
    cat("✗ Collection failed:\n")
    cat(glue("  - Error: {result$error}\n"))
  }

  invisible(result)
}

# =============================================================================
# Example 2: Custom Cache Configuration
# =============================================================================

example_custom_cache <- function() {
  cat("\n=== Example 2: Custom Cache Configuration ===\n\n")

  logger <- create_logger(level = "INFO", console_enabled = TRUE, file_enabled = FALSE)

  # Configuration with shorter cache TTL for testing
  config <- list(
    base_url = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/",
    cache_dir = "data/.cache/cvm_test",  # Separate cache directory
    cache_ttl_days = 7,  # Shorter TTL (1 week instead of 30 days)
    data = list(
      portfolio_file = "data/portfolio.rds"
    ),
    output = "fii_cvm_test.rds"
  )

  collector <- create_cvm_collector(config, logger)
  result <- collector$collect()

  cat(glue("Cache directory: {config$cache_dir}\n"))
  cat(glue("Cache TTL: {config$cache_ttl_days} days\n"))
  cat(glue("Result: {if (result$success) 'SUCCESS' else 'FAILED'}\n"))

  invisible(result)
}

# =============================================================================
# Example 3: Retrieve Historical Data for Analysis
# =============================================================================

example_historical_analysis <- function() {
  cat("\n=== Example 3: Historical Data Analysis ===\n\n")

  # Ensure data exists
  if (!file.exists("data/fii_cvm.rds")) {
    cat("Error: fii_cvm.rds not found. Run collector first.\n")
    return(invisible(NULL))
  }

  # Get 12 months of history for a specific FII
  ticker <- "KNRI11"  # Example ticker with known CNPJ

  cat(glue("Retrieving history for {ticker}...\n"))

  history <- get_fii_cvm_history(ticker, months = 12)

  if (nrow(history) == 0) {
    cat(glue("No data found for {ticker}\n"))
    return(invisible(NULL))
  }

  cat(glue("Found {nrow(history)} months of data\n\n"))

  # Show summary statistics
  cat("Summary statistics:\n")
  cat(glue("  - Date range: {min(history$data_competencia)} to {max(history$data_competencia)}\n"))
  cat(glue("  - Avg patrimônio líquido: R$ {format(mean(history$patrimonio_liquido, na.rm=TRUE), big.mark='.', decimal.mark=',')}\n"))
  cat(glue("  - Avg valor patrimonial/cota: R$ {format(mean(history$valor_patrimonial_cota, na.rm=TRUE), big.mark='.', decimal.mark=',', nsmall=2)}\n"))
  cat(glue("  - Avg DY mensal: {format(mean(history$dividend_yield, na.rm=TRUE), nsmall=2)}%\n"))

  cat("\nRecent data:\n")
  print(
    history %>%
      select(data_competencia, valor_patrimonial_cota, dividend_yield, numero_cotistas) %>%
      head(3)
  )

  invisible(history)
}

# =============================================================================
# Example 4: Integration with Pipeline
# =============================================================================

example_pipeline_integration <- function() {
  cat("\n=== Example 4: Pipeline Integration ===\n\n")

  logger <- create_logger(
    level = "INFO",
    format = "structured",
    console_enabled = TRUE,
    file_enabled = TRUE,
    context = "cvm_pipeline"
  )

  cat(glue("Log file: {logger$get_file_path()}\n\n"))

  # Pipeline configuration
  config <- list(
    collectors = list(
      cvm = list(
        enabled = TRUE,
        base_url = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/",
        cache_dir = "data/.cache/cvm",
        cache_ttl_days = 30,
        output = "fii_cvm.rds"
      )
    ),
    data = list(
      portfolio_file = "data/portfolio.rds"
    )
  )

  # Run CVM collector as part of pipeline
  logger$info("Starting CVM collector in pipeline context")

  cvm_collector <- create_cvm_collector(config$collectors$cvm, logger)
  result <- cvm_collector$collect()

  # Log results
  if (result$success) {
    logger$info("CVM collector completed successfully")
    logger$info(glue("Collected {result$metadata$rows} rows for {result$metadata$tickers_success} tickers"))
  } else {
    logger$error(glue("CVM collector failed: {result$error}"))
  }

  # Get collector stats
  stats <- cvm_collector$get_stats()

  cat("\nCollector statistics:\n")
  cat(glue("  - Name: {stats$name}\n"))
  cat(glue("  - Run count: {stats$run_count}\n"))
  cat(glue("  - Last run: {stats$last_run_time}\n"))
  cat(glue("  - Last run success: {stats$last_run_success}\n"))

  invisible(result)
}

# =============================================================================
# Example 5: Manual Data Fetch for Specific Year
# =============================================================================

example_manual_fetch <- function() {
  cat("\n=== Example 5: Manual Data Fetch ===\n\n")

  logger <- create_logger(level = "DEBUG", console_enabled = TRUE, file_enabled = FALSE)

  # Fetch data for a specific year
  year <- 2026

  cat(glue("Fetching CVM data for year {year}...\n\n"))

  cvm_data <- fetch_cvm_monthly_data(
    year = year,
    base_url = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/",
    cache_dir = "data/.cache/cvm",
    cache_ttl_days = 30,
    logger = logger
  )

  if (!is.null(cvm_data) && nrow(cvm_data) > 0) {
    cat(glue("\n✓ Successfully fetched {nrow(cvm_data)} rows\n"))
    cat(glue("  - Columns: {ncol(cvm_data)}\n"))
    cat(glue("  - Unique funds: {n_distinct(cvm_data$CNPJ_Fundo_Classe)}\n"))

    # Show sample data
    cat("\nSample data (first 3 rows):\n")
    print(head(cvm_data, 3))
  } else {
    cat("✗ Failed to fetch data\n")
  }

  invisible(cvm_data)
}

# =============================================================================
# Example 6: Building and Inspecting CNPJ Mapping
# =============================================================================

example_cnpj_mapping <- function() {
  cat("\n=== Example 6: CNPJ Mapping ===\n\n")

  logger <- create_logger(level = "INFO", console_enabled = TRUE, file_enabled = FALSE)

  cat("Building CNPJ-ticker mapping...\n\n")

  mapping <- build_cnpj_ticker_mapping(logger)

  if (nrow(mapping) > 0) {
    cat(glue("✓ Built mapping for {nrow(mapping)} tickers\n\n"))

    cat("Sample mappings:\n")
    print(head(mapping, 10))

    cat("\nMapping statistics:\n")
    cat(glue("  - Total mappings: {nrow(mapping)}\n"))
    cat(glue("  - Unique tickers: {n_distinct(mapping$ticker)}\n"))
    cat(glue("  - Unique CNPJs: {n_distinct(mapping$cnpj)}\n"))

    # Check for portfolio coverage
    if (file.exists("data/portfolio.rds")) {
      portfolio <- readRDS("data/portfolio.rds")
      portfolio_tickers <- unique(portfolio$ticker)

      covered <- sum(portfolio_tickers %in% mapping$ticker)
      coverage_pct <- round(100 * covered / length(portfolio_tickers), 1)

      cat(glue("\n  - Portfolio coverage: {covered}/{length(portfolio_tickers)} ({coverage_pct}%)\n"))

      missing <- setdiff(portfolio_tickers, mapping$ticker)
      if (length(missing) > 0) {
        cat("\n  Missing mappings for:\n")
        cat(paste("   ", missing, collapse = "\n"))
        cat("\n")
      }
    }
  } else {
    cat("✗ No mappings found\n")
  }

  invisible(mapping)
}

# =============================================================================
# Run All Examples
# =============================================================================

run_all_examples <- function() {
  cat("\n")
  cat(strrep("=", 70))
  cat("\nCVM COLLECTOR USAGE EXAMPLES\n")
  cat(strrep("=", 70))
  cat("\n")

  # Only run examples that don't require collection
  example_cnpj_mapping()

  cat("\n\nTo run data collection examples, call:\n")
  cat("  - example_basic_collection()\n")
  cat("  - example_custom_cache()\n")
  cat("  - example_pipeline_integration()\n")
  cat("  - example_manual_fetch()\n")
  cat("\nTo run analysis examples (requires collected data):\n")
  cat("  - example_historical_analysis()\n")
  cat("\n")
}

# =============================================================================
# Execute (if run as script)
# =============================================================================

if (!interactive()) {
  run_all_examples()
} else {
  cat("\nCVM Collector Usage Examples Loaded\n")
  cat("Run: run_all_examples() to see all examples\n")
  cat("Or call individual examples:\n")
  cat("  - example_basic_collection()\n")
  cat("  - example_custom_cache()\n")
  cat("  - example_historical_analysis()\n")
  cat("  - example_pipeline_integration()\n")
  cat("  - example_manual_fetch()\n")
  cat("  - example_cnpj_mapping()\n\n")
}
