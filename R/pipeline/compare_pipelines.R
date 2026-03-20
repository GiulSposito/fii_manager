# compare_pipelines.R
# Script para comparar outputs do pipeline antigo vs híbrido
# Usa durante migração para validar equivalência

library(dplyr)
library(tidyr)
library(glue)

#' Compare RDS Files
#'
#' Compares two RDS files and reports differences.
#'
#' @param file1 Path to first RDS file
#' @param file2 Path to second RDS file
#' @param tolerance Numeric tolerance for comparisons
#' @return Comparison result list
#' @export
compare_rds <- function(file1, file2, tolerance = 0.01) {
  cat("\n")
  cat("=" %R% 80, "\n")
  cat(glue("Comparing: {basename(file1)} vs {basename(file2)}\n"))
  cat("=" %R% 80, "\n\n")

  # Load files
  if (!file.exists(file1)) {
    cat("✗ File 1 not found:", file1, "\n")
    return(list(equivalent = FALSE, reason = "file1 not found"))
  }

  if (!file.exists(file2)) {
    cat("✗ File 2 not found:", file2, "\n")
    return(list(equivalent = FALSE, reason = "file2 not found"))
  }

  data1 <- readRDS(file1)
  data2 <- readRDS(file2)

  # Compare row counts
  cat("Row counts:\n")
  cat(glue("  File 1: {nrow(data1)}\n"))
  cat(glue("  File 2: {nrow(data2)}\n"))

  diff_rows <- abs(nrow(data1) - nrow(data2))
  pct_diff_rows <- if (nrow(data1) > 0) diff_rows / nrow(data1) * 100 else 0

  cat(glue("  Difference: {diff_rows} rows ({round(pct_diff_rows, 2)}%)\n\n"))

  # Compare columns
  cat("Columns:\n")
  cat(glue("  File 1: {paste(names(data1), collapse=', ')}\n"))
  cat(glue("  File 2: {paste(names(data2), collapse=', ')}\n"))

  missing_in_2 <- setdiff(names(data1), names(data2))
  missing_in_1 <- setdiff(names(data2), names(data1))

  if (length(missing_in_2) > 0) {
    cat(glue("  Missing in File 2: {paste(missing_in_2, collapse=', ')}\n"))
  }

  if (length(missing_in_1) > 0) {
    cat(glue("  Missing in File 1: {paste(missing_in_1, collapse=', ')}\n"))
  }

  cat("\n")

  # Compare common rows
  common_cols <- intersect(names(data1), names(data2))

  if (length(common_cols) == 0) {
    cat("✗ No common columns\n")
    return(list(equivalent = FALSE, reason = "no common columns"))
  }

  # Identify key columns for join
  key_cols <- identify_key_columns(data1, common_cols)
  cat(glue("Using key columns: {paste(key_cols, collapse=', ')}\n\n"))

  # Join datasets
  comparison <- full_join(
    data1 %>% mutate(source = "file1") %>% select(all_of(c(key_cols, common_cols)), source),
    data2 %>% mutate(source = "file2") %>% select(all_of(c(key_cols, common_cols)), source),
    by = key_cols,
    suffix = c("_1", "_2")
  )

  # Count matches
  only_in_1 <- sum(is.na(comparison$source_2))
  only_in_2 <- sum(is.na(comparison$source_1))
  in_both <- nrow(comparison) - only_in_1 - only_in_2

  cat("Row matching:\n")
  cat(glue("  In both: {in_both}\n"))
  cat(glue("  Only in File 1: {only_in_1}\n"))
  cat(glue("  Only in File 2: {only_in_2}\n\n"))

  # Compare values in matching rows
  value_diffs <- list()

  for (col in setdiff(common_cols, key_cols)) {
    col1 <- paste0(col, "_1")
    col2 <- paste0(col, "_2")

    if (!(col1 %in% names(comparison) && col2 %in% names(comparison))) {
      next
    }

    # Compare based on type
    if (is.numeric(comparison[[col1]]) && is.numeric(comparison[[col2]])) {
      diffs <- abs(comparison[[col1]] - comparison[[col2]]) > tolerance
      diff_count <- sum(diffs, na.rm = TRUE)

      if (diff_count > 0) {
        value_diffs[[col]] <- diff_count
        cat(glue("  Column '{col}': {diff_count} differences (>{tolerance})\n"))
      }
    } else {
      diffs <- comparison[[col1]] != comparison[[col2]]
      diff_count <- sum(diffs, na.rm = TRUE)

      if (diff_count > 0) {
        value_diffs[[col]] <- diff_count
        cat(glue("  Column '{col}': {diff_count} differences\n"))
      }
    }
  }

  if (length(value_diffs) == 0) {
    cat("  All values match! ✓\n")
  }

  cat("\n")

  # Determine equivalence
  equivalent <- (
    pct_diff_rows < 1 &&  # <1% row difference
    length(missing_in_1) == 0 &&
    length(missing_in_2) == 0 &&
    length(value_diffs) == 0
  )

  if (equivalent) {
    cat("✓ FILES ARE EQUIVALENT\n")
  } else {
    cat("✗ FILES ARE DIFFERENT\n")

    if (pct_diff_rows >= 1 && pct_diff_rows < 5) {
      cat("  → Row difference acceptable (<5%)\n")
    } else if (pct_diff_rows >= 5) {
      cat("  → Row difference significant (>5%)\n")
    }
  }

  cat("=" %R% 80, "\n\n")

  list(
    equivalent = equivalent,
    row_diff_pct = pct_diff_rows,
    missing_cols_in_2 = missing_in_2,
    missing_cols_in_1 = missing_in_1,
    only_in_1 = only_in_1,
    only_in_2 = only_in_2,
    value_diffs = value_diffs
  )
}

#' Identify Key Columns
#'
#' @keywords internal
identify_key_columns <- function(data, cols) {
  # Common key patterns
  if ("ticker" %in% cols) {
    if ("data_base" %in% cols) {
      return(c("ticker", "data_base"))
    } else if ("date" %in% cols) {
      return(c("ticker", "date"))
    } else {
      return("ticker")
    }
  }

  # Fallback: use first column
  cols[1]
}

#' Compare All Pipeline Outputs
#'
#' Compares all RDS outputs from old vs new pipeline.
#'
#' @param old_dir Directory with old pipeline outputs
#' @param new_dir Directory with new pipeline outputs
#' @param tolerance Numeric tolerance
#' @export
compare_all_outputs <- function(old_dir = "data_old",
                                 new_dir = "data",
                                 tolerance = 0.01) {
  cat("\n")
  cat("=" %R% 80, "\n")
  cat("PIPELINE COMPARISON: Old vs Hybrid\n")
  cat("=" %R% 80, "\n")

  files_to_compare <- c(
    "income.rds",
    "quotations.rds",
    "portfolio.rds",
    "fiis.rds"
  )

  results <- list()

  for (filename in files_to_compare) {
    old_file <- file.path(old_dir, filename)
    new_file <- file.path(new_dir, filename)

    if (file.exists(old_file) && file.exists(new_file)) {
      results[[filename]] <- compare_rds(old_file, new_file, tolerance)
    } else {
      cat(glue("\nSkipping {filename} (not found in both directories)\n\n"))
    }
  }

  # Summary
  cat("=" %R% 80, "\n")
  cat("SUMMARY\n")
  cat("=" %R% 80, "\n\n")

  for (filename in names(results)) {
    result <- results[[filename]]
    status <- if (result$equivalent) "✓ EQUIVALENT" else "✗ DIFFERENT"
    cat(glue("{filename}: {status}\n"))

    if (!result$equivalent) {
      if (result$row_diff_pct > 0) {
        cat(glue("  → {round(result$row_diff_pct, 2)}% row difference\n"))
      }
      if (length(result$value_diffs) > 0) {
        cat(glue("  → {length(result$value_diffs)} columns with differences\n"))
      }
    }
  }

  # Overall verdict
  all_equivalent <- all(sapply(results, function(r) r$equivalent))

  cat("\n")
  if (all_equivalent) {
    cat("🎉 ALL FILES EQUIVALENT - READY TO MIGRATE\n")
  } else {
    # Check if differences are minor
    max_row_diff <- max(sapply(results, function(r) r$row_diff_pct %||% 0))

    if (max_row_diff < 5) {
      cat("⚠️  MINOR DIFFERENCES (<5%) - REVIEW AND DECIDE\n")
    } else {
      cat("❌ SIGNIFICANT DIFFERENCES - INVESTIGATION NEEDED\n")
    }
  }

  cat("=" %R% 80, "\n\n")

  invisible(results)
}

#' Run Pipeline Comparison Test
#'
#' Executes both pipelines and compares outputs.
#'
#' @export
run_comparison_test <- function() {
  cat("\n")
  cat("=" %R% 80, "\n")
  cat("PIPELINE COMPARISON TEST\n")
  cat("=" %R% 80, "\n\n")

  # Step 1: Backup current data
  cat("Step 1: Backing up current data...\n")
  backup_dir <- glue("data_comparison_{format(Sys.time(), '%Y%m%d_%H%M%S')}")
  dir.create(backup_dir, recursive = TRUE)
  file.copy(list.files("data", "*.rds$", full.names = TRUE), backup_dir)
  cat(glue("  Backed up to: {backup_dir}\n\n"))

  # Step 2: Run old pipeline
  cat("Step 2: Running OLD pipeline (pipeline2023.R)...\n")
  old_start <- Sys.time()

  tryCatch({
    source("R/pipeline/pipeline2023.R", local = TRUE)
    old_duration <- as.numeric(difftime(Sys.time(), old_start, units = "secs"))
    cat(glue("  ✓ Old pipeline completed ({round(old_duration, 1)}s)\n\n"))

    # Save old results
    dir.create("data_old", showWarnings = FALSE)
    file.copy(
      list.files("data", "*.rds$", full.names = TRUE),
      "data_old",
      overwrite = TRUE
    )
  },
  error = function(e) {
    cat(glue("  ✗ Old pipeline failed: {e$message}\n\n"))
    return(NULL)
  })

  # Step 3: Run hybrid pipeline
  cat("Step 3: Running HYBRID pipeline (hybrid_pipeline.R)...\n")
  new_start <- Sys.time()

  tryCatch({
    source("R/pipeline/hybrid_pipeline.R", local = TRUE)
    results <- hybrid_pipeline_run()
    new_duration <- as.numeric(difftime(Sys.time(), new_start, units = "secs"))
    cat(glue("  ✓ Hybrid pipeline completed ({round(new_duration, 1)}s)\n\n"))
  },
  error = function(e) {
    cat(glue("  ✗ Hybrid pipeline failed: {e$message}\n\n"))
    return(NULL)
  })

  # Step 4: Compare outputs
  cat("Step 4: Comparing outputs...\n\n")
  comparison <- compare_all_outputs("data_old", "data")

  # Step 5: Performance summary
  if (exists("old_duration") && exists("new_duration")) {
    cat("=" %R% 80, "\n")
    cat("PERFORMANCE COMPARISON\n")
    cat("=" %R% 80, "\n\n")

    cat(glue("Old pipeline: {round(old_duration, 1)}s\n"))
    cat(glue("Hybrid pipeline: {round(new_duration, 1)}s\n"))

    speedup <- old_duration / new_duration
    cat(glue("Speedup: {round(speedup, 2)}x faster\n\n"))

    if (speedup < 1) {
      cat("⚠️  Hybrid is SLOWER - investigate!\n")
    } else if (speedup < 2) {
      cat("✓ Hybrid is faster but below target (3x)\n")
    } else if (speedup >= 3) {
      cat("🎉 Hybrid meets performance target (3x)!\n")
    } else {
      cat("✓ Hybrid is faster\n")
    }

    cat("=" %R% 80, "\n\n")
  }

  invisible(comparison)
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

# Example usage
if (FALSE) {
  # Compare specific files
  compare_rds("data_old/income.rds", "data/income.rds")

  # Compare all outputs
  compare_all_outputs()

  # Full comparison test
  run_comparison_test()
}
