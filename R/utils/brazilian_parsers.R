# brazilian_parsers.R
# Funções consolidadas para parsing de números e datas no formato brasileiro
# Centraliza lógica de parsing que estava duplicada em vários scripts

library(readr)
library(lubridate)
library(stringr)

#' Parse Brazilian Number Format
#'
#' Converts Brazilian number format (comma as decimal, dot as thousands separator)
#' to numeric. Handles currency symbols, percentages, and whitespace.
#'
#' @param x Character vector with Brazilian formatted numbers
#' @param remove_symbols Logical, remove R$, %, etc. Default TRUE
#' @return Numeric vector
#' @examples
#' parse_br_number("R$ 1.234,56")  # 1234.56
#' parse_br_number("8,5%")         # 8.5
#' parse_br_number("1.234.567,89") # 1234567.89
#' @export
parse_br_number <- function(x, remove_symbols = TRUE) {
  if (is.numeric(x)) return(x)
  if (is.null(x) || length(x) == 0) return(numeric(0))

  # Remove símbolos comuns se solicitado
  if (remove_symbols) {
    x <- str_remove_all(x, "R\\$|%|\\s")
  }

  # Parse usando locale brasileiro
  readr::parse_number(
    x,
    locale = locale(
      decimal_mark = ",",
      grouping_mark = "."
    ),
    na = c("", "NA", "-", "N/A", "n/a")
  )
}

#' Parse Brazilian Date Format
#'
#' Converts Brazilian date format (DD/MM/YYYY) to Date object.
#' Handles common date separators (/, -, .) and missing values.
#'
#' @param x Character vector with Brazilian formatted dates
#' @return Date vector
#' @examples
#' parse_br_date("15/03/2026")      # Date: 2026-03-15
#' parse_br_date("28-02-2026")      # Date: 2026-02-28
#' parse_br_date("31.12.2025")      # Date: 2025-12-31
#' @export
parse_br_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (is.null(x) || length(x) == 0) return(as.Date(character(0)))

  # Normaliza separadores para /
  x <- str_replace_all(x, "[-.]", "/")

  # Parse usando lubridate DMY
  lubridate::dmy(x, quiet = TRUE)
}

#' Parse Brazilian Datetime Format
#'
#' Converts Brazilian datetime format to POSIXct object.
#' Handles DD/MM/YYYY HH:MM:SS and variations.
#'
#' @param x Character vector with Brazilian formatted datetimes
#' @param tz Timezone. Default "America/Sao_Paulo"
#' @return POSIXct vector
#' @examples
#' parse_br_datetime("15/03/2026 14:30:00")
#' parse_br_datetime("28-02-2026 09:15")
#' @export
parse_br_datetime <- function(x, tz = "America/Sao_Paulo") {
  if (inherits(x, "POSIXct")) return(x)
  if (is.null(x) || length(x) == 0) return(as.POSIXct(character(0)))

  # Normaliza separadores
  x <- str_replace_all(x, "[-.]", "/")

  # Parse usando lubridate
  lubridate::dmy_hms(x, quiet = TRUE, tz = tz) %||%
    lubridate::dmy_hm(x, quiet = TRUE, tz = tz) %||%
    as.POSIXct(lubridate::dmy(x, quiet = TRUE), tz = tz)
}

#' Check if Value Represents a Percentage
#'
#' Detects if a string contains a percentage indicator.
#'
#' @param x Character vector
#' @return Logical vector
#' @examples
#' is_br_percent("8,5%")    # TRUE
#' is_br_percent("8.5")     # FALSE
#' @export
is_br_percent <- function(x) {
  if (is.null(x) || length(x) == 0) return(logical(0))
  str_detect(x, "%")
}

#' Convert Percentage String to Decimal
#'
#' Converts "8,5%" to 0.085 (decimal form for calculations).
#'
#' @param x Character vector with percentage strings
#' @return Numeric vector (decimal form)
#' @examples
#' parse_br_percent("8,5%")   # 0.085
#' parse_br_percent("10%")    # 0.10
#' @export
parse_br_percent <- function(x) {
  parse_br_number(x, remove_symbols = TRUE) / 100
}

#' Clean Currency String
#'
#' Removes currency symbols and whitespace from strings.
#'
#' @param x Character vector
#' @return Character vector (cleaned)
#' @examples
#' clean_currency("R$ 1.234,56")  # "1.234,56"
#' @export
clean_currency <- function(x) {
  if (is.null(x) || length(x) == 0) return(character(0))
  str_remove_all(x, "R\\$|\\s+")
}

#' Parse Brazilian Ticker Format
#'
#' Validates and standardizes Brazilian FII ticker format (4 letters + 11).
#'
#' @param x Character vector with ticker symbols
#' @param strict Logical, if TRUE only returns valid tickers, else returns as-is
#' @return Character vector (uppercase)
#' @examples
#' parse_br_ticker("alzr11")   # "ALZR11"
#' parse_br_ticker("HGLG11")   # "HGLG11"
#' @export
parse_br_ticker <- function(x, strict = FALSE) {
  if (is.null(x) || length(x) == 0) return(character(0))

  # Uppercase
  x_clean <- str_to_upper(str_trim(x))

  # Valida formato (4 letras + 11)
  valid <- str_detect(x_clean, "^[A-Z]{4}11$")

  if (strict) {
    x_clean[!valid] <- NA_character_
  }

  x_clean
}

#' Coalesce NULL Helper
#'
#' Returns first non-NULL value (similar to dplyr::coalesce but for NULL).
#'
#' @param x First value
#' @param y Second value (fallback)
#' @return x if not NULL, else y
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Safe Parse Wrapper
#'
#' Wraps parsing functions with error handling.
#'
#' @param x Input to parse
#' @param parser Function to use for parsing
#' @param default Default value on error
#' @return Parsed value or default
#' @keywords internal
safe_parse <- function(x, parser, default = NA) {
  tryCatch(
    parser(x),
    error = function(e) {
      warning(sprintf("Parse error: %s. Returning default.", e$message))
      default
    }
  )
}

#' Detect Date Format
#'
#' Attempts to detect if a string is in Brazilian (DMY) or US (MDY) format.
#'
#' @param x Character vector with dates
#' @return Character, "DMY" or "MDY" or "unknown"
#' @keywords internal
detect_date_format <- function(x) {
  # Remove NAs
  x_clean <- x[!is.na(x)]
  if (length(x_clean) == 0) return("unknown")

  # Tenta parsear como DMY
  dmy_success <- sum(!is.na(lubridate::dmy(x_clean, quiet = TRUE)))

  # Tenta parsear como MDY
  mdy_success <- sum(!is.na(lubridate::mdy(x_clean, quiet = TRUE)))

  if (dmy_success > mdy_success) {
    return("DMY")
  } else if (mdy_success > dmy_success) {
    return("MDY")
  } else {
    return("unknown")
  }
}

#' Parse Number with Automatic Format Detection
#'
#' Attempts to detect if number is in BR or US format and parse accordingly.
#'
#' @param x Character vector
#' @return Numeric vector
#' @keywords internal
parse_number_auto <- function(x) {
  if (is.numeric(x)) return(x)

  # Detecta formato pela presença de vírgula como decimal
  # Se tem vírgula seguida de 2 dígitos, assume BR
  has_br_decimal <- str_detect(x, ",\\d{2}($|[^\\d])")

  if (any(has_br_decimal, na.rm = TRUE)) {
    return(parse_br_number(x))
  } else {
    # Assume US format
    return(readr::parse_number(x))
  }
}
