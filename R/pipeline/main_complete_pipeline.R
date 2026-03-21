#' Complete FII Analysis Pipeline v3.0
#'
#' Full-stack orchestrator for FII portfolio management and analysis.
#' Coordinates all pipeline phases: import, clean, transform, deep indicators,
#' persist, analysis, and reporting.
#'
#' Pipeline Phases:
#'   1. IMPORT    - Data collection (hybrid pipeline + CVM)
#'   2. CLEAN     - Data validation and quality checks
#'   3. TRANSFORM - Basic scoring (11 indicators, 4 blocks)
#'   4. DEEP      - Advanced indicators (leverage, momentum, z-scores)
#'   5. PERSIST   - Save results and backups
#'   6. ANALYSIS  - Individual FII deep analysis (optional)
#'   7. REPORT    - Markdown reports generation (optional)
#'
#' @author Claude Code
#' @date 2026-03-21
#' @version 3.0.0

library(tidyverse)
library(lubridate)
library(glue)
library(yaml)

# Load dependencies
source("R/utils/logging.R")
source("R/utils/persistence.R")
source("R/pipeline/hybrid_pipeline.R")
source("R/transform/fii_score_pipeline.R")
source("R/transform/fii_deep_indicators.R")
source("R/import/fii_cvm_data.R")
source("R/validators/cvm_validator.R")

#' Run Complete FII Analysis Pipeline
#'
#' Orchestrates all phases of the FII analysis pipeline from data collection
#' to report generation.
#'
#' @param mode Character, execution mode: "full" (complete refresh) or "incremental" (update only)
#' @param tickers Character, ticker selection: "all", "portfolio", or vector of specific tickers
#' @param include_cvm Logical, collect CVM fundamental data (default: TRUE)
#' @param include_deep_indicators Logical, calculate advanced indicators (default: TRUE)
#' @param include_analysis Logical, generate individual FII analyses (default: FALSE)
#' @param include_reports Logical, generate markdown reports (default: FALSE)
#' @param config_path Character, path to pipeline YAML config (default: config/pipeline_config.yaml)
#' @param log_level Character, logging level: "DEBUG", "INFO", "WARN", "ERROR" (default: "INFO")
#'
#' @return List with phase results, metadata, and execution statistics
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Full pipeline with all data sources
#' result <- run_complete_analysis(mode = "full")
#'
#' # Incremental update, portfolio only, no reports
#' result <- run_complete_analysis(
#'   mode = "incremental",
#'   tickers = "portfolio",
#'   include_analysis = FALSE
#' )
#'
#' # Deep analysis for specific tickers
#' result <- run_complete_analysis(
#'   mode = "incremental",
#'   tickers = c("KNRI11", "MXRF11", "VISC11"),
#'   include_analysis = TRUE,
#'   include_reports = TRUE
#' )
#' }
run_complete_analysis <- function(mode = "full",
                                   tickers = "all",
                                   include_cvm = TRUE,
                                   include_deep_indicators = TRUE,
                                   include_analysis = FALSE,
                                   include_reports = FALSE,
                                   config_path = "config/pipeline_config.yaml",
                                   log_level = "INFO") {

  # ===========================================================================
  # SETUP
  # ===========================================================================

  start_time <- Sys.time()

  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║                                                               ║\n")
  cat("║          FII ANALYSIS PIPELINE v3.0 - COMPLETE               ║\n")
  cat("║                                                               ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

  # Load config
  config <- tryCatch({
    yaml::read_yaml(config_path)
  }, error = function(e) {
    warning(glue("Failed to load config from {config_path}, using defaults"))
    list(
      execution = list(mode = mode, log_level = log_level),
      logging = list(level = log_level, format = "structured"),
      data_sources = list()
    )
  })

  # Override config with parameters
  config$execution$mode <- mode
  config$logging$level <- log_level

  # Setup logger
  logger <- setup_logging(config, context = "complete_pipeline")
  logger$info("╔═══════════════════════════════════════════════════════════════╗")
  logger$info("║ Pipeline v3.0 Started")
  logger$info("╔═══════════════════════════════════════════════════════════════╗")
  logger$info(glue("Mode: {mode}"))
  logger$info(glue("Tickers: {if (length(tickers) == 1) tickers else paste(length(tickers), 'tickers')}"))
  logger$info(glue("CVM data: {include_cvm}"))
  logger$info(glue("Deep indicators: {include_deep_indicators}"))
  logger$info(glue("Analysis: {include_analysis}"))
  logger$info(glue("Reports: {include_reports}"))

  # Initialize results container
  pipeline_results <- list(
    phase_results = list(),
    metadata = list(
      pipeline_version = "3.0.0",
      execution_date = Sys.time(),
      mode = mode,
      config_path = config_path
    ),
    errors = list()
  )

  # ===========================================================================
  # PHASE 1: IMPORT (Data Collection)
  # ===========================================================================

  phase_result <- execute_phase(
    phase_name = "IMPORT",
    phase_num = 1,
    logger = logger,
    fn = function() {
      logger$info("Running hybrid pipeline (existing collectors)...")

      # 1.1 Run hybrid pipeline
      hybrid_results <- tryCatch({
        hybrid_pipeline_run(
          config_path = config_path,
          mode = mode,
          sources = NULL  # All enabled sources
        )
      }, error = function(e) {
        logger$error(glue("Hybrid pipeline failed: {e$message}"))
        list(success = FALSE, error = e$message)
      })

      result <- list(hybrid = hybrid_results)

      # 1.2 Run CVM collector (if enabled)
      if (include_cvm) {
        logger$info("Running CVM data collector...")

        cvm_result <- tryCatch({
          # Create CVM collector config
          cvm_config <- list(
            base_url = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/",
            cache_dir = "data/.cache/cvm",
            cache_ttl_days = 30,
            data = list(portfolio_file = "data/portfolio.rds"),
            output = "fii_cvm.rds"
          )

          cvm_collector <- create_cvm_collector(cvm_config, logger)
          cvm_collector$collect()
        }, error = function(e) {
          logger$error(glue("CVM collection failed: {e$message}"))
          list(success = FALSE, error = e$message)
        })

        result$cvm <- cvm_result

        if (cvm_result$success) {
          logger$info(glue("CVM: ✓ Success ({cvm_result$metadata$rows} rows)"))
        } else {
          logger$warn(glue("CVM: ✗ Failed - {cvm_result$error}"))
        }
      }

      return(result)
    }
  )

  pipeline_results$phase_results$import <- phase_result$result
  if (!is.null(phase_result$error)) {
    pipeline_results$errors$import <- phase_result$error
  }

  # ===========================================================================
  # PHASE 2: CLEAN (Validation)
  # ===========================================================================

  phase_result <- execute_phase(
    phase_name = "CLEAN",
    phase_num = 2,
    logger = logger,
    fn = function() {
      logger$info("Validating data sources...")

      validation_results <- list()

      # 2.1 Validate core RDS files
      logger$info("Checking core data files...")
      core_files <- c(
        "data/portfolio.rds",
        "data/quotations.rds",
        "data/income.rds",
        "data/fiis.rds"
      )

      for (file_path in core_files) {
        if (file.exists(file_path)) {
          file_info <- file.info(file_path)
          age_hours <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "hours"))
          validation_results[[basename(file_path)]] <- list(
            exists = TRUE,
            size_kb = round(file_info$size / 1024, 1),
            age_hours = round(age_hours, 1)
          )
          logger$info(glue("  ✓ {basename(file_path)}: {round(file_info$size/1024, 1)} KB, {round(age_hours, 1)}h old"))
        } else {
          validation_results[[basename(file_path)]] <- list(exists = FALSE)
          logger$warn(glue("  ✗ {basename(file_path)}: NOT FOUND"))
        }
      }

      # 2.2 Validate CVM data (if collected)
      if (include_cvm && file.exists("data/fii_cvm.rds")) {
        logger$info("Validating CVM data...")

        cvm_data <- readRDS("data/fii_cvm.rds")

        # Load other sources for cross-validation
        other_sources <- list()
        if (file.exists("data/fiis.rds")) {
          other_sources$fiis <- readRDS("data/fiis.rds")
        }
        if (file.exists("data/quotations.rds")) {
          other_sources$quotations <- readRDS("data/quotations.rds")
        }

        # Get expected tickers from portfolio
        expected_tickers <- NULL
        if (file.exists("data/portfolio.rds")) {
          portfolio <- readRDS("data/portfolio.rds")
          expected_tickers <- unique(portfolio$ticker)
        }

        cvm_validation <- tryCatch({
          validate_cvm_all(
            cvm_data = cvm_data,
            other_sources = other_sources,
            expected_tickers = expected_tickers,
            logger = logger
          )
        }, error = function(e) {
          logger$error(glue("CVM validation error: {e$message}"))
          list(overall_valid = FALSE, error = e$message)
        })

        validation_results$cvm <- cvm_validation

        if (!cvm_validation$overall_valid) {
          logger$warn("CVM validation issues detected (see details in results)")
        } else {
          logger$info("CVM validation passed")
        }
      }

      return(validation_results)
    }
  )

  pipeline_results$phase_results$clean <- phase_result$result
  if (!is.null(phase_result$error)) {
    pipeline_results$errors$clean <- phase_result$error
  }

  # ===========================================================================
  # PHASE 3: TRANSFORM (Basic Scoring)
  # ===========================================================================

  phase_result <- execute_phase(
    phase_name = "TRANSFORM",
    phase_num = 3,
    logger = logger,
    fn = function() {
      logger$info("Running basic scoring pipeline (11 indicators, 4 blocks)...")

      # Determine tickers to score
      score_tickers <- resolve_tickers(tickers, logger)

      basic_scores <- tryCatch({
        run_scoring_pipeline(
          tickers = score_tickers,
          include_statusinvest = FALSE,  # Use cache only for speed
          force = (mode == "full")
        )
      }, error = function(e) {
        logger$error(glue("Scoring failed: {e$message}"))
        stop(e)
      })

      logger$info(glue("Calculated scores for {nrow(basic_scores)} FIIs"))

      return(basic_scores)
    }
  )

  pipeline_results$phase_results$transform <- phase_result$result
  if (!is.null(phase_result$error)) {
    pipeline_results$errors$transform <- phase_result$error
    logger$error("TRANSFORM phase failed - stopping pipeline")
    return(finalize_pipeline_results(pipeline_results, start_time, logger))
  }

  basic_scores <- phase_result$result

  # ===========================================================================
  # PHASE 4: DEEP INDICATORS (Advanced Metrics)
  # ===========================================================================

  enriched_scores <- basic_scores  # Default to basic if deep disabled

  if (include_deep_indicators) {
    phase_result <- execute_phase(
      phase_name = "DEEP INDICATORS",
      phase_num = 4,
      logger = logger,
      fn = function() {
        logger$info("Loading cache for deep indicators...")

        # Load cache
        cache <- tryCatch({
          load_deep_indicators_cache(
            cvm_file = "data/fii_cvm.rds",
            scores_file = "data/fii_scores.rds",
            fiis_file = "data/fiis.rds",
            history_file = "data/fii_scores_history.rds"
          )
        }, error = function(e) {
          logger$warn(glue("Failed to load full cache: {e$message}"))
          list(cvm_data = NULL, fiis = NULL, scores = NULL, scores_history = NULL)
        })

        logger$info("Enriching scores with deep indicators...")

        enriched <- tryCatch({
          enrich_scores_with_deep_indicators(basic_scores, cache)
        }, error = function(e) {
          logger$error(glue("Deep indicators enrichment failed: {e$message}"))
          logger$warn("Continuing with basic scores only")
          return(basic_scores)
        })

        logger$info(glue("Added {ncol(enriched) - ncol(basic_scores)} deep indicator columns"))

        return(enriched)
      }
    )

    pipeline_results$phase_results$deep <- phase_result$result
    if (!is.null(phase_result$error)) {
      pipeline_results$errors$deep <- phase_result$error
    }

    enriched_scores <- phase_result$result
  } else {
    logger$info("PHASE 4: DEEP INDICATORS - SKIPPED (disabled)")
  }

  # ===========================================================================
  # PHASE 5: PERSIST (Save & Backup)
  # ===========================================================================

  phase_result <- execute_phase(
    phase_name = "PERSIST",
    phase_num = 5,
    logger = logger,
    fn = function() {
      logger$info("Saving enriched scores...")

      persist_results <- list()

      # 5.1 Backup existing files
      logger$info("Creating backups...")
      backup_results <- backup_data_files(
        files = c("data/fii_scores.rds", "data/fii_scores_enriched.rds"),
        backup_dir = "data_backup",
        logger = logger
      )
      persist_results$backups <- backup_results

      # 5.2 Save enriched scores
      output_file <- if (include_deep_indicators) {
        "data/fii_scores_enriched.rds"
      } else {
        "data/fii_scores.rds"
      }

      tryCatch({
        saveRDS(enriched_scores, output_file)
        logger$info(glue("✓ Saved {output_file}"))
        persist_results$main_file <- output_file
      }, error = function(e) {
        logger$error(glue("Failed to save {output_file}: {e$message}"))
        stop(e)
      })

      # 5.3 Export CSV
      csv_file <- sub("\\.rds$", ".csv", output_file)
      tryCatch({
        write_csv(enriched_scores, csv_file)
        logger$info(glue("✓ Exported {csv_file}"))
        persist_results$csv_file <- csv_file
      }, error = function(e) {
        logger$warn(glue("Failed to export CSV: {e$message}"))
      })

      # 5.4 Update metadata
      metadata <- list(
        pipeline_version = "3.0.0",
        execution_date = Sys.time(),
        mode = mode,
        num_fiis = nrow(enriched_scores),
        num_indicators = ncol(enriched_scores),
        has_deep_indicators = include_deep_indicators,
        data_sources = names(pipeline_results$phase_results$import)
      )

      metadata_file <- "data/pipeline_metadata.rds"
      tryCatch({
        saveRDS(metadata, metadata_file)
        logger$info(glue("✓ Saved {metadata_file}"))
        persist_results$metadata <- metadata
      }, error = function(e) {
        logger$warn(glue("Failed to save metadata: {e$message}"))
      })

      return(persist_results)
    }
  )

  pipeline_results$phase_results$persist <- phase_result$result
  if (!is.null(phase_result$error)) {
    pipeline_results$errors$persist <- phase_result$error
  }

  # ===========================================================================
  # PHASE 6: ANALYSIS (Optional - Individual FII Analysis)
  # ===========================================================================

  if (include_analysis) {
    phase_result <- execute_phase(
      phase_name = "ANALYSIS",
      phase_num = 6,
      logger = logger,
      fn = function() {
        logger$info("Running individual FII analyses...")

        # Load analysis script
        if (!file.exists("R/analysis/fii_individual_analysis.R")) {
          logger$warn("Analysis script not found - skipping")
          return(list(skipped = TRUE, reason = "Script not found"))
        }

        source("R/analysis/fii_individual_analysis.R")

        # Get target tickers
        analysis_tickers <- resolve_tickers(tickers, logger)

        # Limit to portfolio if 'all' would be too many
        if (length(analysis_tickers) == 1 && analysis_tickers == "all") {
          if (file.exists("data/portfolio.rds")) {
            portfolio <- readRDS("data/portfolio.rds")
            analysis_tickers <- unique(portfolio$ticker)
            logger$info(glue("Limiting analysis to portfolio tickers: {length(analysis_tickers)} FIIs"))
          } else {
            logger$warn("Portfolio not found - cannot determine analysis tickers")
            return(list(skipped = TRUE, reason = "No portfolio"))
          }
        }

        # Load cache for analysis
        cache <- tryCatch({
          load_deep_indicators_cache()
        }, error = function(e) {
          logger$warn(glue("Cache load failed: {e$message}"))
          list()
        })

        # Run analyses
        logger$info(glue("Analyzing {length(analysis_tickers)} FIIs..."))
        pb <- txtProgressBar(min = 0, max = length(analysis_tickers), style = 3)

        analyses <- map(seq_along(analysis_tickers), function(i) {
          ticker <- analysis_tickers[i]
          setTxtProgressBar(pb, i)

          tryCatch({
            analyze_fii_deep(ticker, cache = cache)
          }, error = function(e) {
            logger$warn(glue("Analysis failed for {ticker}: {e$message}"))
            NULL
          })
        })

        close(pb)

        names(analyses) <- analysis_tickers

        # Save analyses
        analysis_file <- glue("data/fii_analyses_{format(Sys.Date(), '%Y%m%d')}.rds")
        tryCatch({
          saveRDS(analyses, analysis_file)
          logger$info(glue("✓ Saved analyses to {analysis_file}"))
        }, error = function(e) {
          logger$warn(glue("Failed to save analyses: {e$message}"))
        })

        return(list(
          analyses = analyses,
          num_success = sum(!sapply(analyses, is.null)),
          num_failed = sum(sapply(analyses, is.null)),
          output_file = analysis_file
        ))
      }
    )

    pipeline_results$phase_results$analysis <- phase_result$result
    if (!is.null(phase_result$error)) {
      pipeline_results$errors$analysis <- phase_result$error
    }
  } else {
    logger$info("PHASE 6: ANALYSIS - SKIPPED (disabled)")
  }

  # ===========================================================================
  # PHASE 7: REPORT (Optional - Markdown Reports)
  # ===========================================================================

  if (include_reports && include_analysis) {
    phase_result <- execute_phase(
      phase_name = "REPORT",
      phase_num = 7,
      logger = logger,
      fn = function() {
        logger$info("Generating markdown reports...")

        # Create reports directory
        reports_dir <- glue("reports/{format(Sys.Date(), '%Y-%m-%d')}")
        if (!dir.exists(reports_dir)) {
          dir.create(reports_dir, showWarnings = FALSE, recursive = TRUE)
          logger$info(glue("Created directory: {reports_dir}"))
        }

        # Check if we have analyses from Phase 6
        if (is.null(pipeline_results$phase_results$analysis) ||
            is.null(pipeline_results$phase_results$analysis$analyses)) {
          logger$warn("No analyses available - skipping reports")
          return(list(skipped = TRUE, reason = "No analyses"))
        }

        analyses <- pipeline_results$phase_results$analysis$analyses
        report_paths <- list()

        # Generate individual reports
        logger$info("Generating individual FII reports...")
        successful_reports <- 0

        for (ticker in names(analyses)) {
          analysis <- analyses[[ticker]]

          if (is.null(analysis)) {
            next
          }

          tryCatch({
            # Format report (use markdown formatter if available)
            report_content <- format_fii_analysis_markdown(analysis)

            # Write to file
            report_file <- file.path(reports_dir, glue("{ticker}_analysis.md"))
            writeLines(report_content, report_file)

            report_paths[[ticker]] <- report_file
            successful_reports <- successful_reports + 1
          }, error = function(e) {
            logger$warn(glue("Report generation failed for {ticker}: {e$message}"))
          })
        }

        logger$info(glue("Generated {successful_reports} individual reports"))

        # Generate opportunities summary (if available)
        if (file.exists("R/analysis/fii_opportunities.R")) {
          logger$info("Generating opportunities report...")

          tryCatch({
            source("R/analysis/fii_opportunities.R")

            opportunities <- identify_opportunities(
              scores = enriched_scores,
              user_profile = NULL,  # Use defaults
              min_score = 65
            )

            # Format and save
            opp_report <- format_opportunities_markdown(opportunities)
            opp_file <- file.path(reports_dir, "opportunities_summary.md")
            writeLines(opp_report, opp_file)

            report_paths$opportunities <- opp_file
            logger$info(glue("✓ Saved opportunities report: {opp_file}"))
          }, error = function(e) {
            logger$warn(glue("Opportunities report failed: {e$message}"))
          })
        }

        return(list(
          reports_dir = reports_dir,
          num_reports = length(report_paths),
          report_paths = report_paths
        ))
      }
    )

    pipeline_results$phase_results$report <- phase_result$result
    if (!is.null(phase_result$error)) {
      pipeline_results$errors$report <- phase_result$error
    }
  } else {
    if (include_reports && !include_analysis) {
      logger$info("PHASE 7: REPORT - SKIPPED (requires analysis to be enabled)")
    } else {
      logger$info("PHASE 7: REPORT - SKIPPED (disabled)")
    }
  }

  # ===========================================================================
  # FINALIZE
  # ===========================================================================

  return(finalize_pipeline_results(pipeline_results, start_time, logger))
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

#' Execute Phase with Error Handling
#'
#' Wrapper for phase execution with standardized logging and error handling.
#'
#' @param phase_name Character, phase name
#' @param phase_num Integer, phase number
#' @param logger Logger instance
#' @param fn Function to execute
#' @return List with result and optional error
#' @keywords internal
execute_phase <- function(phase_name, phase_num, logger, fn) {
  logger$info("")
  logger$info("═" %R% 63)
  logger$info(glue("PHASE {phase_num}: {phase_name}"))
  logger$info("═" %R% 63)

  phase_start <- Sys.time()

  result <- list(result = NULL, error = NULL)

  tryCatch({
    result$result <- fn()
    phase_duration <- as.numeric(difftime(Sys.time(), phase_start, units = "secs"))
    logger$info(glue("✅ PHASE {phase_num} COMPLETE ({round(phase_duration, 1)}s)"))
  }, error = function(e) {
    phase_duration <- as.numeric(difftime(Sys.time(), phase_start, units = "secs"))
    logger$error(glue("❌ PHASE {phase_num} FAILED ({round(phase_duration, 1)}s)"))
    logger$error(glue("Error: {e$message}"))
    result$error <<- e$message
  })

  return(result)
}

#' Resolve Tickers from Parameter
#'
#' Converts ticker parameter to actual vector of tickers.
#'
#' @param tickers Character, "all", "portfolio", or vector
#' @param logger Logger instance
#' @return Character vector of tickers or "all"
#' @keywords internal
resolve_tickers <- function(tickers, logger) {
  if (length(tickers) == 1) {
    if (tickers == "all") {
      return("all")
    } else if (tickers == "portfolio") {
      if (file.exists("data/portfolio.rds")) {
        portfolio <- readRDS("data/portfolio.rds")
        resolved <- unique(portfolio$ticker)
        logger$info(glue("Resolved 'portfolio' to {length(resolved)} tickers"))
        return(resolved)
      } else {
        logger$warn("Portfolio file not found, using 'all'")
        return("all")
      }
    }
  }

  return(tickers)
}

#' Backup Data Files
#'
#' Creates timestamped backups of data files.
#'
#' @param files Character vector of file paths
#' @param backup_dir Character, backup directory
#' @param logger Logger instance
#' @return List with backup results
#' @keywords internal
backup_data_files <- function(files, backup_dir = "data_backup", logger = NULL) {
  if (!dir.exists(backup_dir)) {
    dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE)
  }

  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_results <- list()

  for (file_path in files) {
    if (!file.exists(file_path)) {
      next
    }

    filename <- basename(file_path)
    backup_name <- glue("{tools::file_path_sans_ext(filename)}_{timestamp}.{tools::file_ext(filename)}")
    backup_path <- file.path(backup_dir, backup_name)

    tryCatch({
      file.copy(file_path, backup_path, overwrite = FALSE)
      backup_results[[filename]] <- backup_path

      if (!is.null(logger)) {
        logger$debug(glue("Backed up {filename} → {backup_name}"))
      }
    }, error = function(e) {
      if (!is.null(logger)) {
        logger$warn(glue("Backup failed for {filename}: {e$message}"))
      }
    })
  }

  if (!is.null(logger) && length(backup_results) > 0) {
    logger$info(glue("Created {length(backup_results)} backups in {backup_dir}"))
  }

  return(backup_results)
}

#' Finalize Pipeline Results
#'
#' Adds execution summary and logs final statistics.
#'
#' @param pipeline_results List with phase results
#' @param start_time POSIXct start time
#' @param logger Logger instance
#' @return Final results list
#' @keywords internal
finalize_pipeline_results <- function(pipeline_results, start_time, logger) {
  end_time <- Sys.time()
  total_duration <- as.numeric(difftime(end_time, start_time, units = "secs"))

  # Count phases
  completed_phases <- names(pipeline_results$phase_results)
  failed_phases <- names(pipeline_results$errors)

  # Determine overall success
  overall_success <- length(failed_phases) == 0 ||
                     !any(c("import", "transform") %in% failed_phases)

  # Add execution summary
  pipeline_results$summary <- list(
    overall_success = overall_success,
    completed_phases = completed_phases,
    failed_phases = failed_phases,
    total_duration_secs = total_duration,
    start_time = start_time,
    end_time = end_time
  )

  # Log summary
  logger$info("")
  logger$info("╔═══════════════════════════════════════════════════════════════╗")
  logger$info("║ PIPELINE EXECUTION SUMMARY")
  logger$info("╚═══════════════════════════════════════════════════════════════╝")
  logger$info(glue("Status: {if (overall_success) '✅ SUCCESS' else '❌ FAILED'}"))
  logger$info(glue("Duration: {round(total_duration, 1)}s ({format_duration(total_duration)})"))
  logger$info(glue("Completed phases: {length(completed_phases)}"))

  if (length(failed_phases) > 0) {
    logger$warn(glue("Failed phases: {paste(failed_phases, collapse=', ')}"))
  }

  # Output file summary
  if (!is.null(pipeline_results$phase_results$persist)) {
    persist <- pipeline_results$phase_results$persist
    logger$info("")
    logger$info("📁 Output Files:")
    if (!is.null(persist$main_file)) {
      logger$info(glue("  • {persist$main_file} (primary output)"))
    }
    if (!is.null(persist$csv_file)) {
      logger$info(glue("  • {persist$csv_file} (CSV export)"))
    }
  }

  # Analysis summary
  if (!is.null(pipeline_results$phase_results$analysis)) {
    analysis <- pipeline_results$phase_results$analysis
    if (!is.null(analysis$num_success)) {
      logger$info("")
      logger$info("📊 Analysis:")
      logger$info(glue("  • {analysis$num_success} FIIs analyzed"))
      if (analysis$num_failed > 0) {
        logger$warn(glue("  • {analysis$num_failed} analyses failed"))
      }
    }
  }

  # Report summary
  if (!is.null(pipeline_results$phase_results$report)) {
    report <- pipeline_results$phase_results$report
    if (!is.null(report$num_reports)) {
      logger$info("")
      logger$info("📄 Reports:")
      logger$info(glue("  • {report$num_reports} reports in {report$reports_dir}"))
    }
  }

  logger$info("")
  logger$info("╔═══════════════════════════════════════════════════════════════╗")
  logger$info("║ ✅ PIPELINE COMPLETED")
  logger$info("╚═══════════════════════════════════════════════════════════════╝")
  logger$info("")

  return(pipeline_results)
}

#' Format Duration
#'
#' Formats duration in human-readable form.
#'
#' @param seconds Numeric seconds
#' @return Character formatted duration
#' @keywords internal
format_duration <- function(seconds) {
  if (seconds < 60) {
    return(glue("{round(seconds, 1)}s"))
  } else if (seconds < 3600) {
    minutes <- floor(seconds / 60)
    secs <- seconds %% 60
    return(glue("{minutes}m {round(secs)}s"))
  } else {
    hours <- floor(seconds / 3600)
    minutes <- floor((seconds %% 3600) / 60)
    return(glue("{hours}h {minutes}m"))
  }
}

#' Format FII Analysis as Markdown
#'
#' Placeholder for markdown formatter (implement in analysis script).
#'
#' @param analysis Analysis result
#' @return Character vector with markdown content
#' @keywords internal
format_fii_analysis_markdown <- function(analysis) {
  # Fallback basic formatter
  ticker <- analysis$ticker %||% "UNKNOWN"

  content <- c(
    glue("# Análise: {ticker}"),
    "",
    glue("**Data:** {format(Sys.Date(), '%d/%m/%Y')}"),
    "",
    "## Resumo",
    "",
    glue("Score Total: {analysis$score$total_score %||% 'N/A'}"),
    glue("Recomendação: {analysis$score$recommendation %||% 'N/A'}"),
    "",
    "## Indicadores Básicos",
    "",
    glue("- DY 12m: {format(analysis$score$dy_12m %||% NA, digits=2)}%"),
    glue("- P/VP: {format(analysis$score$pvp %||% NA, digits=2)}"),
    glue("- Liquidez: {analysis$score$liquidez_score %||% 'N/A'}"),
    "",
    "---",
    "",
    "*Gerado pelo Pipeline FII v3.0*"
  )

  return(content)
}

#' Format Opportunities Report as Markdown
#'
#' Placeholder for opportunities markdown formatter.
#'
#' @param opportunities Opportunities result
#' @return Character vector with markdown content
#' @keywords internal
format_opportunities_markdown <- function(opportunities) {
  content <- c(
    "# Oportunidades de Investimento - FIIs",
    "",
    glue("**Data:** {format(Sys.Date(), '%d/%m/%Y')}"),
    "",
    "## Top Oportunidades",
    ""
  )

  if (!is.null(opportunities$top_opportunities) && nrow(opportunities$top_opportunities) > 0) {
    for (i in seq_len(min(10, nrow(opportunities$top_opportunities)))) {
      opp <- opportunities$top_opportunities[i, ]
      content <- c(
        content,
        glue("### {i}. {opp$ticker}"),
        "",
        glue("- **Score:** {round(opp$total_score, 1)}"),
        glue("- **DY 12m:** {format(opp$dy_12m, digits=2)}%"),
        glue("- **P/VP:** {format(opp$pvp, digits=2)}"),
        glue("- **Recomendação:** {opp$recommendation}"),
        ""
      )
    }
  }

  content <- c(
    content,
    "---",
    "",
    "*Gerado pelo Pipeline FII v3.0*"
  )

  return(content)
}

#' String Repeat Helper
#' @keywords internal
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}

#' Coalesce NULL Helper
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
