# recovery_manager.R
# Gerenciamento de recuperação de falhas parciais
# Permite retomar pipeline a partir de checkpoints

library(jsonlite)
library(glue)

#' Save Pipeline Checkpoint
#'
#' Saves current pipeline state to allow recovery.
#'
#' @param results Current results list
#' @param checkpoint_dir Directory for checkpoints
#' @param logger Logger instance
#' @export
save_checkpoint <- function(results, checkpoint_dir = "data/.checkpoints", logger = NULL) {
  if (!dir.exists(checkpoint_dir)) {
    dir.create(checkpoint_dir, recursive = TRUE)
  }

  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  checkpoint_file <- file.path(checkpoint_dir, glue("checkpoint_{timestamp}.json"))

  tryCatch({
    # Prepare checkpoint data
    checkpoint_data <- list(
      timestamp = Sys.time(),
      results = lapply(results, function(r) {
        if (is.data.frame(r$data)) {
          r$data <- NULL  # Don't save data, just metadata
        }
        r
      })
    )

    # Save as JSON
    jsonlite::write_json(
      checkpoint_data,
      checkpoint_file,
      pretty = TRUE,
      auto_unbox = TRUE
    )

    if (!is.null(logger)) {
      logger$info(glue("Checkpoint saved: {checkpoint_file}"))
    }

    checkpoint_file
  },
  error = function(e) {
    if (!is.null(logger)) {
      logger$warn(glue("Failed to save checkpoint: {e$message}"))
    }
    NULL
  })
}

#' Load Pipeline Checkpoint
#'
#' Loads most recent checkpoint.
#'
#' @param checkpoint_dir Directory with checkpoints
#' @param logger Logger instance
#' @return Checkpoint data or NULL
#' @export
load_checkpoint <- function(checkpoint_dir = "data/.checkpoints", logger = NULL) {
  if (!dir.exists(checkpoint_dir)) {
    return(NULL)
  }

  # Find most recent checkpoint
  checkpoints <- list.files(
    checkpoint_dir,
    pattern = "^checkpoint_.*\\.json$",
    full.names = TRUE
  )

  if (length(checkpoints) == 0) {
    return(NULL)
  }

  # Sort by mtime, get most recent
  checkpoint_file <- checkpoints[order(file.mtime(checkpoints), decreasing = TRUE)][1]

  tryCatch({
    checkpoint_data <- jsonlite::read_json(checkpoint_file, simplifyVector = TRUE)

    if (!is.null(logger)) {
      logger$info(glue("Checkpoint loaded: {checkpoint_file}"))
    }

    checkpoint_data
  },
  error = function(e) {
    if (!is.null(logger)) {
      logger$warn(glue("Failed to load checkpoint: {e$message}"))
    }
    NULL
  })
}

#' Resume Pipeline from Checkpoint
#'
#' Resumes pipeline execution from last successful state.
#'
#' @param checkpoint Checkpoint data
#' @param config Pipeline config
#' @param logger Logger instance
#' @return List of sources to skip
#' @export
get_completed_sources <- function(checkpoint, config, logger = NULL) {
  if (is.null(checkpoint)) {
    return(character(0))
  }

  completed <- names(checkpoint$results)[
    sapply(checkpoint$results, function(r) r$success %||% FALSE)
  ]

  if (!is.null(logger) && length(completed) > 0) {
    logger$info(glue("Skipping completed sources: {paste(completed, collapse=', ')}"))
  }

  completed
}

#' Clean Old Checkpoints
#'
#' Removes checkpoints older than specified days.
#'
#' @param checkpoint_dir Directory with checkpoints
#' @param keep_days Keep checkpoints from last N days
#' @param logger Logger instance
#' @return Number of files removed
#' @export
clean_old_checkpoints <- function(checkpoint_dir = "data/.checkpoints",
                                   keep_days = 7,
                                   logger = NULL) {
  if (!dir.exists(checkpoint_dir)) {
    return(0)
  }

  checkpoints <- list.files(
    checkpoint_dir,
    pattern = "^checkpoint_.*\\.json$",
    full.names = TRUE
  )

  if (length(checkpoints) == 0) {
    return(0)
  }

  cutoff_date <- Sys.time() - (keep_days * 24 * 60 * 60)
  removed <- 0

  for (file in checkpoints) {
    mtime <- file.info(file)$mtime
    if (mtime < cutoff_date) {
      tryCatch({
        file.remove(file)
        removed <- removed + 1
        if (!is.null(logger)) {
          logger$debug(glue("Removed old checkpoint: {basename(file)}"))
        }
      },
      error = function(e) {
        if (!is.null(logger)) {
          logger$warn(glue("Failed to remove {basename(file)}: {e$message}"))
        }
      })
    }
  }

  if (!is.null(logger) && removed > 0) {
    logger$info(glue("Cleaned {removed} old checkpoints"))
  }

  removed
}

#' Retry Failed Sources
#'
#' Extracts failed sources from results for retry.
#'
#' @param results Pipeline results
#' @param logger Logger instance
#' @return Character vector of failed source names
#' @export
get_failed_sources <- function(results, logger = NULL) {
  failed <- names(results)[
    sapply(results, function(r) {
      !is.null(r$success) && !r$success
    })
  ]

  if (!is.null(logger) && length(failed) > 0) {
    logger$info(glue("Failed sources for retry: {paste(failed, collapse=', ')}"))
  }

  failed
}

#' Create Recovery Plan
#'
#' Analyzes results and creates recovery plan.
#'
#' @param results Pipeline results
#' @param config Pipeline config
#' @param logger Logger instance
#' @return Recovery plan list
#' @export
create_recovery_plan <- function(results, config, logger = NULL) {
  plan <- list()

  # Identify failed sources
  failed <- get_failed_sources(results, logger)

  # Identify critical failures
  critical_failed <- character(0)
  for (source_name in failed) {
    source_config <- config$data_sources[[source_name]]
    if (source_config$critical %||% FALSE) {
      critical_failed <- c(critical_failed, source_name)
    }
  }

  # Identify sources with fallbacks
  has_fallback <- character(0)
  for (source_name in failed) {
    if (!is.null(config$fallback[[source_name]])) {
      has_fallback <- c(has_fallback, source_name)
    }
  }

  plan$failed_sources <- failed
  plan$critical_failures <- critical_failed
  plan$has_fallback <- has_fallback
  plan$can_retry <- setdiff(failed, has_fallback)

  # Recovery strategy
  if (length(critical_failed) > 0) {
    plan$strategy <- "critical_retry"
    plan$priority <- critical_failed
  } else if (length(has_fallback) > 0) {
    plan$strategy <- "fallback"
    plan$priority <- has_fallback
  } else if (length(failed) > 0) {
    plan$strategy <- "retry_all"
    plan$priority <- failed
  } else {
    plan$strategy <- "none"
    plan$priority <- character(0)
  }

  if (!is.null(logger)) {
    logger$info("=" %R% 60)
    logger$info("Recovery Plan")
    logger$info("=" %R% 60)
    logger$info(glue("Strategy: {plan$strategy}"))
    logger$info(glue("Failed sources: {length(failed)}"))
    logger$info(glue("Critical failures: {length(critical_failed)}"))
    logger$info(glue("With fallback: {length(has_fallback)}"))
    logger$info(glue("Can retry: {length(plan$can_retry)}"))

    if (length(plan$priority) > 0) {
      logger$info(glue("Priority: {paste(plan$priority, collapse=', ')}"))
    }
  }

  plan
}

#' Execute Recovery
#'
#' Executes recovery plan by retrying failed sources.
#'
#' @param plan Recovery plan
#' @param config Pipeline config
#' @param logger Logger instance
#' @return Updated results
#' @export
execute_recovery <- function(plan, config, logger = NULL) {
  if (plan$strategy == "none") {
    if (!is.null(logger)) {
      logger$info("No recovery needed")
    }
    return(list())
  }

  if (!is.null(logger)) {
    logger$info("=" %R% 60)
    logger$info("Executing Recovery")
    logger$info("=" %R% 60)
  }

  # This would call hybrid_pipeline_run with sources = plan$priority
  # For now, return instruction

  recovery_instruction <- list(
    action = "rerun_pipeline",
    sources = plan$priority,
    strategy = plan$strategy
  )

  if (!is.null(logger)) {
    logger$info(glue("Recovery action: {recovery_instruction$action}"))
    logger$info(glue("Rerun sources: {paste(recovery_instruction$sources, collapse=', ')}"))
  }

  recovery_instruction
}

#' Helper: String Repeat
#' @keywords internal
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}
