# test_parsers.R
# Unit tests for Brazilian parsers
# Run with: source("tests/test_parsers.R")

library(testthat)
source("R/utils/brazilian_parsers.R")

test_that("parse_br_number handles currency format", {
  expect_equal(parse_br_number("R$ 1.234,56"), 1234.56)
  expect_equal(parse_br_number("R$1.234,56"), 1234.56)
  expect_equal(parse_br_number("1.234,56"), 1234.56)
})

test_that("parse_br_number handles percentages", {
  expect_equal(parse_br_number("8,5%"), 8.5)
  expect_equal(parse_br_number("10%"), 10)
  expect_equal(parse_br_number("0,5%"), 0.5)
})

test_that("parse_br_number handles large numbers", {
  expect_equal(parse_br_number("1.234.567,89"), 1234567.89)
  expect_equal(parse_br_number("1.000.000,00"), 1000000)
})

test_that("parse_br_number handles simple numbers", {
  expect_equal(parse_br_number("123,45"), 123.45)
  expect_equal(parse_br_number("0,5"), 0.5)
})

test_that("parse_br_number handles edge cases", {
  expect_equal(parse_br_number("0"), 0)
  expect_true(is.na(parse_br_number("")))
  expect_true(is.na(parse_br_number("-")))
  expect_true(is.na(parse_br_number("N/A")))
})

test_that("parse_br_date handles DMY format", {
  expect_equal(parse_br_date("15/03/2026"), as.Date("2026-03-15"))
  expect_equal(parse_br_date("28/02/2026"), as.Date("2026-02-28"))
  expect_equal(parse_br_date("31/12/2025"), as.Date("2025-12-31"))
})

test_that("parse_br_date handles different separators", {
  expect_equal(parse_br_date("15-03-2026"), as.Date("2026-03-15"))
  expect_equal(parse_br_date("15.03.2026"), as.Date("2026-03-15"))
})

test_that("parse_br_date handles invalid dates", {
  expect_true(is.na(parse_br_date("")))
  expect_true(is.na(parse_br_date("invalid")))
})

test_that("parse_br_percent converts to decimal", {
  expect_equal(parse_br_percent("8,5%"), 0.085)
  expect_equal(parse_br_percent("10%"), 0.10)
  expect_equal(parse_br_percent("100%"), 1.0)
})

test_that("is_br_percent detects percentages", {
  expect_true(is_br_percent("8,5%"))
  expect_true(is_br_percent("10%"))
  expect_false(is_br_percent("8.5"))
  expect_false(is_br_percent("10"))
})

test_that("parse_br_ticker standardizes format", {
  expect_equal(parse_br_ticker("alzr11"), "ALZR11")
  expect_equal(parse_br_ticker("HGLG11"), "HGLG11")
  expect_equal(parse_br_ticker("  xpml11  "), "XPML11")
})

test_that("parse_br_ticker validates format in strict mode", {
  expect_equal(parse_br_ticker("ALZR11", strict = TRUE), "ALZR11")
  expect_true(is.na(parse_br_ticker("INVALID", strict = TRUE)))
  expect_true(is.na(parse_br_ticker("ALZ11", strict = TRUE)))  # Somente 4 letras
})

test_that("clean_currency removes symbols", {
  expect_equal(clean_currency("R$ 1.234,56"), "1.234,56")
  expect_equal(clean_currency("R$   1.234,56"), "1.234,56")
})

# Run all tests
cat("\n")
cat("=" %R% 60, "\n")
cat("Running Brazilian Parser Tests\n")
cat("=" %R% 60, "\n\n")

test_results <- test_file("tests/test_parsers.R", reporter = "summary")

cat("\n")
cat("=" %R% 60, "\n")
cat("Test Results Summary\n")
cat("=" %R% 60, "\n")
print(test_results)

# Helper from logging.R
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}
