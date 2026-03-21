#' Ticker Utility Functions
#'
#' Shared utility functions for extracting and manipulating FII tickers.
#'

#' Extract ticker from ticker name
#'
#' Extracts the FII ticker from various formats including:
#' - "MXRF11.SA" -> "MXRF11"
#' - "BTHF11..." -> "BTHF11"
#' - "KNHF11Kinea..." -> "KNHF11"
#'
#' @param ticker_string String containing ticker (with or without .SA suffix, with or without name)
#' @return Clean ticker (e.g., "MXRF11", "BTHF11")
#' @export
#' @examples
#' extractTicker("MXRF11.SA")       # "MXRF11"
#' extractTicker("BTHF11...")       # "BTHF11"
#' extractTicker("KNHF11Kinea...")  # "KNHF11"
extractTicker <- function(ticker_string) {
  # Remove .SA suffix if present
  ticker_clean <- gsub("\\.SA$", "", ticker_string)

  # Extract ticker pattern: 4 letters + 2 digits + optional 1 letter
  ticker <- stringr::str_extract(ticker_clean, "^[A-Z]{4}[0-9]{2}[A-Z]?")

  return(ticker)
}

#' Add .SA suffix to ticker for Yahoo Finance
#'
#' @param ticker Clean ticker (e.g., "MXRF11")
#' @return Ticker with .SA suffix (e.g., "MXRF11.SA")
#' @export
#' @examples
#' addYahooSuffix("MXRF11")  # "MXRF11.SA"
addYahooSuffix <- function(ticker) {
  if (!grepl("\\.SA$", ticker)) {
    return(paste0(ticker, ".SA"))
  }
  return(ticker)
}

#' Remove .SA suffix from ticker
#'
#' @param ticker Ticker with or without .SA suffix
#' @return Clean ticker without suffix
#' @export
#' @examples
#' removeYahooSuffix("MXRF11.SA")  # "MXRF11"
#' removeYahooSuffix("MXRF11")     # "MXRF11"
removeYahooSuffix <- function(ticker) {
  return(gsub("\\.SA$", "", ticker))
}
