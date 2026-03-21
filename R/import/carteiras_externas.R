# Import external portfolios from Google Sheets
# Source: https://docs.google.com/spreadsheets/d/1BOCeqV9Xa0TPd6IsTa8wdcTMGY3rIomxZq7k77GU1ls/edit?usp=sharing

library(googlesheets4)
library(tidyverse)

# Spreadsheet ID
CARTEIRAS_EXTERNAS_ID <- "1BOCeqV9Xa0TPd6IsTa8wdcTMGY3rIomxZq7k77GU1ls"

#' Import external portfolios data
#'
#' Downloads portfolio data from external Google Sheets source
#' Saves as separate datasets (not linked to main portfolio)
#'
#' @return List with 3 portfolio dataframes
importCarteirasExternas <- function() {

  # Get sheet names
  sheet_names <- googlesheets4::sheet_names(CARTEIRAS_EXTERNAS_ID)

  message("Found ", length(sheet_names), " sheets: ", paste(sheet_names, collapse = ", "))

  # Import all sheets
  carteiras <- purrr::map(sheet_names, function(sheet) {
    message("Importing sheet: ", sheet)
    googlesheets4::read_sheet(CARTEIRAS_EXTERNAS_ID, sheet = sheet)
  })

  names(carteiras) <- sheet_names

  # Save to data/ directory
  saveRDS(carteiras, "data/carteiras_externas.rds")
  message("Saved to data/carteiras_externas.rds")

  return(carteiras)
}

# Run if sourced directly
if (interactive()) {
  carteiras_externas <- importCarteirasExternas()

  # Print summary
  for (nome in names(carteiras_externas)) {
    cat("\n=== Carteira:", nome, "===\n")
    print(glimpse(carteiras_externas[[nome]]))
  }
}
