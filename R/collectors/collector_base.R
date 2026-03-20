# collector_base.R
# Base collector pattern with common functionality
# Provides standard interface for all data collectors in the pipeline

library(glue)

#' Create Base Collector
#'
#' Creates a base collector with standard interface and common functionality.
#' All collectors should follow this pattern for consistency.
#'
#' @param name Character, name of the collector (e.g., "portfolio", "income")
#' @param config List with configuration parameters
#' @param logger Logger instance from logging.R
#' @param collect_fn Function that performs the actual data collection
#'   Should accept (config, logger) and return list(success, data, error)
#' @return Collector instance (list of methods)
#' @export
create_base_collector <- function(name, config, logger, collect_fn) {

  # Validação
  if (is.null(name) || !is.character(name)) {
    stop("Collector name must be a character string")
  }

  if (is.null(logger)) {
    stop("Logger instance is required")
  }

  if (is.null(collect_fn) || !is.function(collect_fn)) {
    stop("collect_fn must be a function")
  }

  # Estado interno
  state <- new.env()
  state$last_run_time <- NULL
  state$last_run_success <- NULL
  state$last_run_error <- NULL
  state$run_count <- 0

  # Collect method - executa a coleta com error handling padrão
  collect <- function() {
    logger$info(glue("[{name}] Starting data collection"))
    start_time <- Sys.time()

    result <- tryCatch({
      # Chama a função de coleta específica
      collect_result <- collect_fn(config, logger)

      # Valida formato do resultado
      if (!is.list(collect_result)) {
        stop("collect_fn must return a list")
      }

      if (!("success" %in% names(collect_result))) {
        stop("collect_fn result must contain 'success' field")
      }

      # Atualiza estado
      state$last_run_time <- Sys.time()
      state$last_run_success <- collect_result$success
      state$last_run_error <- collect_result$error
      state$run_count <- state$run_count + 1

      if (collect_result$success) {
        duration <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
        logger$info(glue("[{name}] Collection successful ({round(duration, 2)}s)"))
      } else {
        duration <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
        error_msg <- collect_result$error %||% "Unknown error"
        logger$error(glue("[{name}] Collection failed ({round(duration, 2)}s): {error_msg}"))
      }

      collect_result
    },
    error = function(e) {
      duration <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      logger$error(glue("[{name}] Collection error ({round(duration, 2)}s): {e$message}"))

      state$last_run_time <- Sys.time()
      state$last_run_success <- FALSE
      state$last_run_error <- e$message
      state$run_count <- state$run_count + 1

      list(
        success = FALSE,
        data = NULL,
        error = e$message
      )
    })

    result
  }

  # Retorna collector como lista de métodos
  list(
    name = name,
    collect = collect,
    get_stats = function() {
      list(
        name = name,
        run_count = state$run_count,
        last_run_time = state$last_run_time,
        last_run_success = state$last_run_success,
        last_run_error = state$last_run_error
      )
    }
  )
}

#' Create Standard Collection Result
#'
#' Helper to create standardized result objects from collectors.
#'
#' @param success Logical, whether collection succeeded
#' @param data Data collected (tibble/data.frame) or NULL on failure
#' @param error Character error message or NULL on success
#' @param metadata Optional list with additional info (rows_collected, etc.)
#' @return List with standard result format
#' @export
create_result <- function(success, data = NULL, error = NULL, metadata = NULL) {
  result <- list(
    success = success,
    data = data,
    error = error
  )

  # Adiciona metadata se fornecida
  if (!is.null(metadata)) {
    result$metadata <- metadata
  }

  # Adiciona contagem de linhas se data for data frame
  if (!is.null(data) && is.data.frame(data)) {
    result$rows <- nrow(data)
  }

  result
}

#' Validate Collector Result
#'
#' Validates that a collector result has the expected structure.
#'
#' @param result Result object from collector
#' @param required_fields Character vector of required field names in data
#' @param logger Logger instance (optional)
#' @return Logical, TRUE if valid
#' @export
validate_result <- function(result, required_fields = NULL, logger = NULL) {
  # Verifica estrutura básica
  if (!is.list(result)) {
    if (!is.null(logger)) {
      logger$error("Result is not a list")
    }
    return(FALSE)
  }

  if (!("success" %in% names(result))) {
    if (!is.null(logger)) {
      logger$error("Result missing 'success' field")
    }
    return(FALSE)
  }

  if (!is.logical(result$success)) {
    if (!is.null(logger)) {
      logger$error("'success' field must be logical")
    }
    return(FALSE)
  }

  # Se não teve sucesso, deve ter erro
  if (!result$success && is.null(result$error)) {
    if (!is.null(logger)) {
      logger$warn("Failed result missing error message")
    }
  }

  # Se teve sucesso, verifica data
  if (result$success) {
    if (is.null(result$data)) {
      if (!is.null(logger)) {
        logger$error("Successful result missing data")
      }
      return(FALSE)
    }

    # Verifica campos obrigatórios se especificado
    if (!is.null(required_fields) && is.data.frame(result$data)) {
      missing <- setdiff(required_fields, names(result$data))
      if (length(missing) > 0) {
        if (!is.null(logger)) {
          logger$error(glue("Result data missing fields: {paste(missing, collapse=', ')}"))
        }
        return(FALSE)
      }
    }
  }

  TRUE
}

#' Coalesce NULL Helper
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
