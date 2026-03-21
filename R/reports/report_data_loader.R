#' Report Data Loader
#'
#' Load and validate all required data files for portfolio analysis report
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(lubridate)
library(glue)

#' Load all data files for report
#'
#' @param base_dir Base directory for data files (default: auto-detect project root)
#' @return List with all loaded data
#' @export
load_report_data <- function(base_dir = NULL) {

  # Auto-detect project root
  if (is.null(base_dir)) {
    # Try to find project root by looking for CLAUDE.md or .git
    current_dir <- getwd()

    # Check common locations
    possible_roots <- c(
      current_dir,
      dirname(current_dir),
      "/Users/gsposito/Projects/fii_manager"
    )

    for (root in possible_roots) {
      if (file.exists(file.path(root, "CLAUDE.md")) ||
          file.exists(file.path(root, ".git"))) {
        base_dir <- root
        break
      }
    }

    if (is.null(base_dir)) {
      base_dir <- "/Users/gsposito/Projects/fii_manager"
    }
  }

  # Paths
  csv_path <- "/tmp/portfolio_with_dividends.csv"
  md_path <- "/tmp/portfolio_final_summary.md"

  data_dir <- file.path(base_dir, "data")
  portfolio_path <- file.path(data_dir, "portfolio.rds")
  scores_path <- file.path(data_dir, "fii_scores_enriched.rds")
  income_path <- file.path(data_dir, "income.rds")
  quotations_path <- file.path(data_dir, "quotations.rds")

  # Validate file existence
  required_files <- c(
    csv = csv_path,
    md = md_path,
    portfolio = portfolio_path,
    scores = scores_path,
    income = income_path,
    quotations = quotations_path
  )

  missing_files <- required_files[!file.exists(required_files)]

  if (length(missing_files) > 0) {
    stop(glue(
      "Missing required files:\n",
      "{paste('  -', names(missing_files), ':', missing_files, collapse = '\n')}"
    ))
  }

  cat("Loading data files...\n")

  # Load CSV data
  cat("  - portfolio_with_dividends.csv\n")
  portfolio_csv <- read_csv(csv_path, show_col_types = FALSE) %>%
    mutate(
      first_purchase = as_date(first_purchase),
      # Handle NA values
      current_value = ifelse(is.na(current_value), invested, current_value),
      total_dividends = ifelse(is.na(total_dividends), 0, total_dividends),
      return_with_div = ifelse(is.na(return_with_div), -0.999, return_with_div),
      div_yield_on_cost = ifelse(is.na(div_yield_on_cost), 0, div_yield_on_cost)
    )

  # Load markdown summary
  cat("  - portfolio_final_summary.md\n")
  summary_text <- readLines(md_path, encoding = "UTF-8") %>%
    paste(collapse = "\n")

  # Load RDS files
  cat("  - portfolio.rds\n")
  portfolio <- readRDS(portfolio_path)

  cat("  - fii_scores_enriched.rds\n")
  scores <- readRDS(scores_path)

  cat("  - income.rds\n")
  income <- readRDS(income_path)

  cat("  - quotations.rds\n")
  quotations <- readRDS(quotations_path)

  # Empiricus portfolios (optional)
  empiricus_renda <- NULL
  empiricus_tatica <- NULL

  empiricus_renda_path <- file.path(data_dir, "portfolios", "empiricus_renda.rds")
  empiricus_tatica_path <- file.path(data_dir, "portfolios", "empiricus_tatica.rds")

  if (file.exists(empiricus_renda_path)) {
    cat("  - empiricus_renda.rds\n")
    empiricus_renda <- readRDS(empiricus_renda_path)
  }

  if (file.exists(empiricus_tatica_path)) {
    cat("  - empiricus_tatica.rds\n")
    empiricus_tatica <- readRDS(empiricus_tatica_path)
  }

  cat("Data loading complete!\n\n")

  # Return list
  list(
    portfolio_csv = portfolio_csv,
    summary_text = summary_text,
    portfolio = portfolio,
    scores = scores,
    income = income,
    quotations = quotations,
    empiricus_renda = empiricus_renda,
    empiricus_tatica = empiricus_tatica,
    load_time = Sys.time()
  )
}

#' Validate loaded data
#'
#' @param data List from load_report_data()
#' @return TRUE if valid, error otherwise
#' @export
validate_report_data <- function(data) {

  # Check portfolio CSV has expected columns
  expected_cols <- c(
    "ticker", "invested", "current_value", "total_dividends",
    "return_with_div", "div_yield_on_cost", "months_held"
  )

  missing_cols <- setdiff(expected_cols, names(data$portfolio_csv))

  if (length(missing_cols) > 0) {
    stop(glue(
      "Missing columns in portfolio_csv:\n",
      "{paste('  -', missing_cols, collapse = '\n')}"
    ))
  }

  # Check row count
  n_fiis <- nrow(data$portfolio_csv)

  if (n_fiis == 0) {
    stop("portfolio_csv is empty!")
  }

  cat(glue("Validation passed: {n_fiis} FIIs loaded\n"))

  TRUE
}
