# http_client.R
# HTTP client moderno usando httr2 com retry automático, rate limiting,
# circuit breaker, e logging estruturado

library(httr2)
library(glue)

#' Create HTTP Client
#'
#' Creates an HTTP client with retry, rate limiting, and logging capabilities.
#' Uses httr2 for modern HTTP handling.
#'
#' @param config List with configuration parameters
#'   - base_url: Base URL for requests
#'   - timeout_seconds: Request timeout
#'   - rate_limit: List with delay_between_requests
#'   - retry: List with max_attempts and backoff_factor
#'   - user_agent: Optional user agent string
#' @param logger Logger instance (optional)
#' @return List with HTTP client methods
#' @export
create_http_client <- function(config, logger = NULL) {
  # Estado interno do client
  state <- new.env()
  state$last_request_time <- Sys.time() - 999
  state$request_count <- 0
  state$error_count <- 0
  state$circuit_open <- FALSE
  state$circuit_open_until <- Sys.time()

  # Configurações padrão
  timeout <- config$timeout_seconds %||% 30
  rate_delay <- config$rate_limit$delay_between_requests %||% 1.0
  max_attempts <- config$retry$max_attempts %||% 3
  backoff_factor <- config$retry$backoff_factor %||% 2
  user_agent <- config$user_agent %||% "fiiscrapeR/2.0 (R httr2)"
  base_url <- config$base_url %||% ""

  # Helper: aplicar rate limiting
  apply_rate_limit <- function() {
    elapsed <- as.numeric(difftime(Sys.time(), state$last_request_time, units = "secs"))
    if (elapsed < rate_delay) {
      sleep_time <- rate_delay - elapsed
      if (!is.null(logger)) {
        logger$debug(glue("Rate limit: sleeping {round(sleep_time, 2)}s"))
      }
      Sys.sleep(sleep_time)
    }
    state$last_request_time <- Sys.time()
  }

  # Helper: verifica circuit breaker
  check_circuit <- function() {
    if (state$circuit_open) {
      if (Sys.time() < state$circuit_open_until) {
        stop(glue("Circuit breaker open until {state$circuit_open_until}"))
      } else {
        # Reseta circuit breaker
        state$circuit_open <- FALSE
        state$error_count <- 0
        if (!is.null(logger)) {
          logger$info("Circuit breaker closed - retrying requests")
        }
      }
    }
  }

  # Helper: abre circuit breaker após muitos erros
  open_circuit <- function() {
    state$circuit_open <- TRUE
    state$circuit_open_until <- Sys.time() + 60  # 1 minuto
    if (!is.null(logger)) {
      logger$error(glue("Circuit breaker opened - too many errors ({state$error_count})"))
    }
  }

  # GET request
  get_request <- function(url, query = NULL, headers = NULL, ...) {
    check_circuit()
    apply_rate_limit()

    full_url <- if (str_detect(url, "^https?://")) url else paste0(base_url, url)

    if (!is.null(logger)) {
      logger$debug(glue("GET {full_url}"))
    }

    req <- request(full_url) %>%
      req_timeout(timeout) %>%
      req_user_agent(user_agent) %>%
      req_retry(
        max_tries = max_attempts,
        backoff = ~ backoff_factor ^ .x
      )

    # Adiciona query parameters
    if (!is.null(query)) {
      req <- req_url_query(req, !!!query)
    }

    # Adiciona headers
    if (!is.null(headers)) {
      req <- req_headers(req, !!!headers)
    }

    # Executa request
    tryCatch({
      resp <- req_perform(req, ...)

      state$request_count <- state$request_count + 1

      if (!is.null(logger)) {
        logger$debug(glue("Response: {resp_status(resp)} ({resp_status_desc(resp)})"))
      }

      # Reseta error count em sucesso
      state$error_count <- max(0, state$error_count - 1)

      return(resp)
    },
    error = function(e) {
      state$error_count <- state$error_count + 1

      if (!is.null(logger)) {
        logger$error(glue("Request failed: {e$message}"))
      }

      # Abre circuit breaker após 5 erros consecutivos
      if (state$error_count >= 5) {
        open_circuit()
      }

      stop(e)
    })
  }

  # POST request
  post_request <- function(url, body = NULL, headers = NULL, encode = "json", ...) {
    check_circuit()
    apply_rate_limit()

    full_url <- if (str_detect(url, "^https?://")) url else paste0(base_url, url)

    if (!is.null(logger)) {
      logger$debug(glue("POST {full_url}"))
    }

    req <- request(full_url) %>%
      req_timeout(timeout) %>%
      req_user_agent(user_agent) %>%
      req_retry(
        max_tries = max_attempts,
        backoff = ~ backoff_factor ^ .x
      ) %>%
      req_method("POST")

    # Adiciona body
    if (!is.null(body)) {
      req <- req_body_json(req, body)
    }

    # Adiciona headers
    if (!is.null(headers)) {
      req <- req_headers(req, !!!headers)
    }

    # Executa request
    tryCatch({
      resp <- req_perform(req, ...)

      state$request_count <- state$request_count + 1

      if (!is.null(logger)) {
        logger$debug(glue("Response: {resp_status(resp)} ({resp_status_desc(resp)})"))
      }

      # Reseta error count em sucesso
      state$error_count <- max(0, state$error_count - 1)

      return(resp)
    },
    error = function(e) {
      state$error_count <- state$error_count + 1

      if (!is.null(logger)) {
        logger$error(glue("Request failed: {e$message}"))
      }

      # Abre circuit breaker após 5 erros consecutivos
      if (state$error_count >= 5) {
        open_circuit()
      }

      stop(e)
    })
  }

  # Retorna client como lista de métodos
  list(
    get = get_request,
    post = post_request,
    stats = function() {
      list(
        request_count = state$request_count,
        error_count = state$error_count,
        circuit_open = state$circuit_open
      )
    },
    reset_circuit = function() {
      state$circuit_open <- FALSE
      state$error_count <- 0
      if (!is.null(logger)) {
        logger$info("Circuit breaker manually reset")
      }
    }
  )
}

#' Extract Response Body as Text
#'
#' @param resp httr2 response object
#' @return Character string
#' @export
resp_body_string <- function(resp) {
  httr2::resp_body_string(resp)
}

#' Extract Response Body as JSON
#'
#' @param resp httr2 response object
#' @return Parsed JSON (list or data.frame)
#' @export
resp_body_json_parsed <- function(resp) {
  httr2::resp_body_json(resp)
}

#' Check if Response is Successful (2xx)
#'
#' @param resp httr2 response object
#' @return Logical
#' @export
is_response_success <- function(resp) {
  status <- httr2::resp_status(resp)
  status >= 200 && status < 300
}

#' Check if Response is Auth Error (401/403)
#'
#' @param resp httr2 response object
#' @return Logical
#' @export
is_auth_error <- function(resp) {
  status <- httr2::resp_status(resp)
  status %in% c(401, 403)
}

#' Coalesce NULL Helper
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Parse Response with Error Handling
#'
#' Wraps response parsing with structured error handling.
#'
#' @param resp httr2 response object
#' @param parser Function to parse response body
#' @param logger Logger instance (optional)
#' @return Parsed response or NULL on error
#' @export
safe_parse_response <- function(resp, parser = resp_body_json_parsed, logger = NULL) {
  tryCatch({
    parser(resp)
  },
  error = function(e) {
    if (!is.null(logger)) {
      logger$error(glue("Failed to parse response: {e$message}"))
    }
    NULL
  })
}
