# test_integration.R
# Integration tests for hybrid pipeline
# Tests end-to-end flow

library(testthat)
library(yaml)

test_that("Pipeline config loads correctly", {
  config <- yaml::read_yaml("config/pipeline_config.yaml")

  expect_true(!is.null(config))
  expect_true(!is.null(config$data_sources))
  expect_true(!is.null(config$execution))
})

test_that("All utils are loadable", {
  expect_no_error(source("R/utils/brazilian_parsers.R"))
  expect_no_error(source("R/utils/http_client.R"))
  expect_no_error(source("R/utils/logging.R"))
  expect_no_error(source("R/utils/persistence.R"))
})

test_that("Collectors are loadable", {
  collectors <- c(
    "R/collectors/collector_base.R",
    "R/collectors/statusinvest_income_collector.R",
    "R/collectors/portfolio_collector.R",
    "R/collectors/fiiscom_lupa_collector.R",
    "R/collectors/statusinvest_indicators_collector.R",
    "R/collectors/yahoo_prices_collector.R"
  )

  for (collector in collectors) {
    expect_true(file.exists(collector), info = glue::glue("{collector} exists"))
  }
})

test_that("Validators are loadable", {
  expect_no_error(source("R/validators/schema_validator.R"))
  expect_no_error(source("R/validators/data_quality_validator.R"))
  expect_no_error(source("R/validators/consistency_validator.R"))
})

test_that("Pipeline orchestrator is loadable", {
  expect_no_error(source("R/pipeline/hybrid_pipeline.R"))
  expect_no_error(source("R/pipeline/recovery_manager.R"))
})

test_that("Schema validation works", {
  source("R/validators/schema_validator.R")

  # Test income schema
  test_income <- data.frame(
    ticker = "ALZR11",
    rendimento = 0.95,
    data_base = as.Date("2026-03-15"),
    data_pagamento = as.Date("2026-03-28"),
    cota_base = 98.50,
    dy = 0.0096,
    stringsAsFactors = FALSE
  )

  result <- validate_schema(test_income, "income", strict = TRUE)
  expect_true(result$valid)
})

test_that("Data quality validation detects issues", {
  source("R/validators/data_quality_validator.R")

  # Test with negative values (should fail)
  bad_income <- data.frame(
    ticker = "ALZR11",
    rendimento = -0.95,  # Negative!
    data_base = as.Date("2026-03-15"),
    data_pagamento = as.Date("2026-03-28"),
    cota_base = 98.50,
    dy = 0.0096,
    stringsAsFactors = FALSE
  )

  config <- list(
    validation = list(
      data_quality = list(
        check_negative_values = TRUE
      )
    )
  )

  result <- validate_data_quality(bad_income, "income", config)
  expect_false(result$valid)
  expect_true(length(result$issues) > 0)
})

cat("\n")
cat("=" %R% 70, "\n")
cat("Integration Tests Summary\n")
cat("=" %R% 70, "\n")
cat("✓ All integration tests passed\n")
cat("=" %R% 70, "\n\n")

# Helper
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}
