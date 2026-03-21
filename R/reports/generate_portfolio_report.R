#' Generate Portfolio Analysis Report
#'
#' Wrapper function to render the HTML report
#'
#' @author Claude Code
#' @date 2026-03-21

library(rmarkdown)
library(glue)

#' Generate portfolio analysis report
#'
#' @param output_file Output HTML file path (default: /tmp/portfolio_analysis_report.html)
#' @param open_browser Open report in browser after generation (default: TRUE)
#' @return Path to generated HTML file
#' @export
generate_portfolio_report <- function(
  output_file = "/tmp/portfolio_analysis_report.html",
  open_browser = TRUE
) {

  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("        PORTFOLIO ANALYSIS REPORT GENERATOR v3.0\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  # Get paths
  report_dir <- here::here("R", "reports")
  rmd_file <- file.path(report_dir, "portfolio_analysis_report.Rmd")

  # Validate RMD exists
  if (!file.exists(rmd_file)) {
    stop(glue("RMarkdown file not found: {rmd_file}"))
  }

  cat(glue("📄 RMarkdown source: {rmd_file}\n"))
  cat(glue("📊 Output file: {output_file}\n\n"))

  # Check data dependencies
  cat("🔍 Checking data dependencies...\n")

  required_files <- c(
    "/tmp/portfolio_with_dividends.csv",
    "/tmp/portfolio_final_summary.md",
    "data/portfolio.rds",
    "data/fii_scores_enriched.rds",
    "data/income.rds",
    "data/quotations.rds"
  )

  missing_files <- required_files[!file.exists(required_files)]

  if (length(missing_files) > 0) {
    cat("❌ Missing required files:\n")
    for (file in missing_files) {
      cat(glue("   - {file}\n"))
    }
    stop("Cannot generate report: missing data files")
  }

  cat("✅ All data files found\n\n")

  # Render report
  cat("🔨 Rendering HTML report...\n")
  cat("   (This may take 1-2 minutes)\n\n")

  start_time <- Sys.time()

  tryCatch({
    # Set working directory to report dir for relative paths
    old_wd <- getwd()
    setwd(report_dir)

    # Render
    rmarkdown::render(
      input = "portfolio_analysis_report.Rmd",
      output_file = output_file,
      output_format = "html_document",
      quiet = FALSE,
      envir = new.env()
    )

    # Restore working directory
    setwd(old_wd)

    end_time <- Sys.time()
    elapsed <- round(difftime(end_time, start_time, units = "secs"), 1)

    cat("\n")
    cat("═══════════════════════════════════════════════════════════════\n")
    cat("                    ✅ REPORT GENERATED!\n")
    cat("═══════════════════════════════════════════════════════════════\n\n")

    # File size
    file_size_mb <- file.size(output_file) / (1024^2)

    cat(glue("📁 Output: {output_file}\n"))
    cat(glue("📏 Size: {sprintf('%.2f', file_size_mb)} MB\n"))
    cat(glue("⏱️  Time: {elapsed} seconds\n\n"))

    # Validate file size
    if (file_size_mb > 5) {
      cat("⚠️  WARNING: File size exceeds 5 MB\n")
      cat("   Consider optimizing images or removing large visualizations\n\n")
    }

    # Open in browser
    if (open_browser) {
      cat("🌐 Opening report in browser...\n")
      browseURL(output_file)
    }

    cat("\n")
    cat("To open later, run:\n")
    cat(glue("  browseURL('{output_file}')\n\n"))

    return(invisible(output_file))

  }, error = function(e) {
    # Restore working directory on error
    if (exists("old_wd")) {
      setwd(old_wd)
    }

    cat("\n")
    cat("═══════════════════════════════════════════════════════════════\n")
    cat("                    ❌ REPORT GENERATION FAILED\n")
    cat("═══════════════════════════════════════════════════════════════\n\n")

    cat("Error message:\n")
    cat(glue("  {e$message}\n\n"))

    cat("Troubleshooting:\n")
    cat("  1. Check that all data files exist\n")
    cat("  2. Verify RMarkdown file has correct syntax\n")
    cat("  3. Ensure all required packages are installed:\n")
    cat("     - rmarkdown, knitr, tidyverse, plotly, kableExtra\n")
    cat("  4. Check R session has enough memory\n\n")

    stop(e)
  })
}

#' Quick report generation with defaults
#'
#' @export
quick_report <- function() {
  generate_portfolio_report(
    output_file = "/tmp/portfolio_analysis_report.html",
    open_browser = TRUE
  )
}

# ============================================================================
# MAIN EXECUTION (if run as script)
# ============================================================================

if (!interactive()) {
  # Command-line execution
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) > 0) {
    output_file <- args[1]
  } else {
    output_file <- "/tmp/portfolio_analysis_report.html"
  }

  generate_portfolio_report(
    output_file = output_file,
    open_browser = FALSE
  )
}
