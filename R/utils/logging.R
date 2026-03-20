# logging.R
# Sistema de logging estruturado para o pipeline
# Suporta níveis de log, output para arquivo e console, formato estruturado

library(glue)
library(lubridate)

#' Create Logger Instance
#'
#' Creates a logger with configurable level, format, and output destinations.
#'
#' @param level Character, one of "DEBUG", "INFO", "WARN", "ERROR"
#' @param format Character, "simple" or "structured"
#' @param file_enabled Logical, write to file
#' @param file_path Character, path to log file
#' @param console_enabled Logical, write to console
#' @param context Character, optional context identifier (e.g., "income_collector")
#' @return Logger instance (list of methods)
#' @export
create_logger <- function(level = "INFO",
                          format = "structured",
                          file_enabled = TRUE,
                          file_path = NULL,
                          console_enabled = TRUE,
                          context = NULL) {

  # Hierarquia de níveis
  levels <- c("DEBUG" = 1, "INFO" = 2, "WARN" = 3, "ERROR" = 4)
  current_level <- levels[[toupper(level)]]

  # Gera path do arquivo se não fornecido
  if (file_enabled && is.null(file_path)) {
    log_dir <- "data/.logs"
    if (!dir.exists(log_dir)) {
      dir.create(log_dir, recursive = TRUE)
    }
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    file_path <- file.path(log_dir, glue("pipeline_{timestamp}.log"))
  }

  # Helper: formatar mensagem
  format_message <- function(level_name, message, ..., .envir = parent.frame()) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    extra_fields <- list(...)

    if (format == "structured") {
      # Formato estruturado (JSON-like)
      fields <- c(
        glue("timestamp=\"{timestamp}\""),
        glue("level={level_name}"),
        if (!is.null(context)) glue("context=\"{context}\""),
        glue("message=\"{glue(message, .envir = .envir)}\"")
      )

      # Adiciona campos extras
      if (length(extra_fields) > 0) {
        extra_str <- sapply(names(extra_fields), function(name) {
          value <- extra_fields[[name]]
          if (is.character(value)) {
            glue("{name}=\"{value}\"")
          } else {
            glue("{name}={value}")
          }
        })
        fields <- c(fields, extra_str)
      }

      paste(fields, collapse=" ")
    } else {
      # Formato simples
      ctx <- if (!is.null(context)) glue("[{context}] ") else ""
      glue("{timestamp} {level_name} {ctx}{glue(message, .envir = .envir)}")
    }
  }

  # Helper: escrever log
  write_log <- function(formatted_message) {
    # Console
    if (console_enabled) {
      cat(formatted_message, "\n", file = stdout())
    }

    # Arquivo
    if (file_enabled) {
      tryCatch({
        cat(formatted_message, "\n", file = file_path, append = TRUE)
      },
      error = function(e) {
        warning(glue("Failed to write to log file: {e$message}"))
      })
    }
  }

  # Métodos públicos
  logger <- list()

  logger$debug <- function(message, ..., .envir = parent.frame()) {
    if (current_level <= levels[["DEBUG"]]) {
      formatted <- format_message("DEBUG", message, ..., .envir = .envir)
      write_log(formatted)
    }
    invisible(NULL)
  }

  logger$info <- function(message, ..., .envir = parent.frame()) {
    if (current_level <= levels[["INFO"]]) {
      formatted <- format_message("INFO", message, ..., .envir = .envir)
      write_log(formatted)
    }
    invisible(NULL)
  }

  logger$warn <- function(message, ..., .envir = parent.frame()) {
    if (current_level <= levels[["WARN"]]) {
      formatted <- format_message("WARN", message, ..., .envir = .envir)
      write_log(formatted)
    }
    invisible(NULL)
  }

  logger$error <- function(message, ..., .envir = parent.frame()) {
    if (current_level <= levels[["ERROR"]]) {
      formatted <- format_message("ERROR", message, ..., .envir = .envir)
      write_log(formatted)
    }
    invisible(NULL)
  }

  logger$set_context <- function(new_context) {
    context <<- new_context
    invisible(NULL)
  }

  logger$get_context <- function() {
    context
  }

  logger$set_level <- function(new_level) {
    current_level <<- levels[[toupper(new_level)]]
    invisible(NULL)
  }

  logger$get_file_path <- function() {
    file_path
  }

  logger
}

#' Setup Logging from Config
#'
#' Creates a logger instance from YAML config.
#'
#' @param config List with logging configuration
#' @param context Optional context identifier
#' @return Logger instance
#' @export
setup_logging <- function(config, context = NULL) {
  log_config <- config$logging %||% config$execution

  create_logger(
    level = log_config$level %||% log_config$log_level %||% "INFO",
    format = log_config$format %||% "structured",
    file_enabled = log_config$file_enabled %||% TRUE,
    file_path = NULL,  # Auto-generate
    console_enabled = log_config$console_enabled %||% TRUE,
    context = context
  )
}

#' Log Execution Summary
#'
#' Logs a structured summary of pipeline execution.
#'
#' @param logger Logger instance
#' @param results List with execution results from collectors
#' @export
log_execution_summary <- function(logger, results) {
  logger$info("=" %R% 60)
  logger$info("Pipeline Execution Summary")
  logger$info("=" %R% 60)

  total <- length(results)
  success <- sum(sapply(results, function(r) r$success %||% FALSE))
  failed <- total - success

  logger$info(glue("Total collectors: {total}"))
  logger$info(glue("Successful: {success}"))
  logger$info(glue("Failed: {failed}"))

  if (failed > 0) {
    logger$warn("Some collectors failed:")
    for (name in names(results)) {
      if (!results[[name]]$success) {
        error_msg <- results[[name]]$error %||% "Unknown error"
        logger$warn(glue("  - {name}: {error_msg}"))
      }
    }
  }

  logger$info("=" %R% 60)
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

#' Log Function Execution Time
#'
#' Wrapper that logs execution time of a function.
#'
#' @param logger Logger instance
#' @param fn Function to execute
#' @param description Character description
#' @param ... Arguments passed to fn
#' @return Result of fn
#' @export
log_execution_time <- function(logger, fn, description, ...) {
  logger$info(glue("Starting: {description}"))
  start_time <- Sys.time()

  result <- tryCatch({
    fn(...)
  },
  error = function(e) {
    end_time <- Sys.time()
    duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
    logger$error(glue("Failed: {description} ({round(duration, 2)}s)"), error = e$message)
    stop(e)
  })

  end_time <- Sys.time()
  duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
  logger$info(glue("Completed: {description} ({round(duration, 2)}s)"))

  result
}

#' Create Progress Logger
#'
#' Creates a simple progress tracker for iterative operations.
#'
#' @param logger Logger instance
#' @param total Integer, total number of items
#' @param description Character description
#' @return Progress logger function
#' @export
create_progress_logger <- function(logger, total, description) {
  current <- 0

  function(increment = 1) {
    current <<- current + increment
    pct <- round(100 * current / total, 1)
    logger$info(glue("{description}: {current}/{total} ({pct}%)"))
  }
}
