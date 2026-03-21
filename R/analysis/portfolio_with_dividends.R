#!/usr/bin/env Rscript
# Portfolio Analysis Including Dividend Income
# Created: 2026-03-21

library(tidyverse)
library(lubridate)

# Load data files
portfolio <- readRDS("data/portfolio.rds")
income <- readRDS("data/income.rds")
scores <- readRDS("data/fii_scores_enriched.rds")
quotations <- readRDS("data/quotations.rds")

cat("\n=== PORTFOLIO WITH DIVIDENDS ANALYSIS ===\n")
cat("Date:", format(Sys.Date(), "%Y-%m-%d"), "\n\n")

# 1. Prepare portfolio data
cat("Step 1: Processing portfolio data...\n")

# Get current portfolio positions with dates
portfolio_summary <- portfolio %>%
  group_by(ticker) %>%
  summarise(
    qtde_total = sum(volume, na.rm = TRUE),
    first_purchase = min(date, na.rm = TRUE),
    invested = sum(price * volume, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(qtde_total > 0)

cat("Portfolio positions:", nrow(portfolio_summary), "\n")
cat("Tickers:", paste(portfolio_summary$ticker, collapse = ", "), "\n\n")

# 2. Get current prices
cat("Step 2: Getting current prices...\n")

current_prices <- quotations %>%
  group_by(ticker) %>%
  filter(date == max(date)) %>%
  select(ticker, price) %>%
  distinct()

# Merge with portfolio
portfolio_summary <- portfolio_summary %>%
  left_join(current_prices, by = "ticker") %>%
  rename(current_price = price) %>%
  mutate(
    current_value = qtde_total * current_price,
    return_without_div = (current_value - invested) / invested
  )

# 3. Calculate dividends received
cat("Step 3: Calculating dividends received since purchase...\n")

# Process income data (using data_pagamento as payment date and rendimento as value)
income_processed <- income %>%
  mutate(
    ticker = toupper(ticker),
    data_pagamento = as.Date(data_pagamento),
    rendimento = as.numeric(rendimento)
  ) %>%
  filter(!is.na(data_pagamento), !is.na(rendimento))

# For each position, sum dividends from first purchase date
dividends_by_ticker <- portfolio_summary %>%
  select(ticker, qtde_total, first_purchase) %>%
  left_join(
    income_processed %>%
      select(ticker, data_pagamento, rendimento),
    by = "ticker",
    relationship = "many-to-many"
  ) %>%
  filter(data_pagamento >= first_purchase) %>%
  group_by(ticker, qtde_total, first_purchase) %>%
  summarise(
    div_count = n(),
    div_per_share = sum(rendimento, na.rm = TRUE),
    div_total = sum(rendimento, na.rm = TRUE) * first(qtde_total),
    last_div_date = max(data_pagamento, na.rm = TRUE),
    .groups = "drop"
  )

# 4. Estimate missing dividends
cat("Step 4: Estimating missing dividends for data gaps...\n")

# Get DY data from scores
dy_data <- scores %>%
  select(ticker, dy_12m) %>%
  mutate(
    ticker = toupper(ticker),
    dy_12m = as.numeric(dy_12m)
  ) %>%
  filter(!is.na(dy_12m))

# Calculate months held and expected dividend count
portfolio_with_divs <- portfolio_summary %>%
  left_join(dividends_by_ticker, by = c("ticker", "qtde_total", "first_purchase")) %>%
  left_join(dy_data, by = "ticker") %>%
  mutate(
    # Replace NA with 0 for tickers with no dividend records
    div_count = replace_na(div_count, 0),
    div_per_share = replace_na(div_per_share, 0),
    div_total = replace_na(div_total, 0),

    # Calculate holding period
    months_held = interval(first_purchase, Sys.Date()) / months(1),
    months_held = ceiling(pmax(1, months_held)),

    # Expected dividend payments (monthly payments)
    expected_div_count = months_held,

    # Missing dividend months
    missing_months = pmax(0, expected_div_count - div_count),

    # Estimate missing dividends using DY
    avg_div_per_month = if_else(div_count > 0,
                                  div_per_share / div_count,
                                  (current_price * dy_12m / 100) / 12),

    estimated_missing_div = missing_months * avg_div_per_month * qtde_total,

    # Total dividends (actual + estimated)
    total_dividends = div_total + estimated_missing_div,

    # Total return including dividends
    return_with_div = (current_value + total_dividends - invested) / invested,

    # Dividend yield on investment
    div_yield_on_cost = total_dividends / invested
  )

# 5. Generate comprehensive report
cat("\n=== DETAILED ANALYSIS BY TICKER ===\n\n")

report_lines <- c()
report_lines <- c(report_lines, strrep("=", 80))
report_lines <- c(report_lines, "PORTFOLIO DIVIDEND ANALYSIS - DETAILED REPORT")
report_lines <- c(report_lines, paste("Date:", format(Sys.Date(), "%Y-%m-%d")))
report_lines <- c(report_lines, strrep("=", 80))
report_lines <- c(report_lines, "")

for (i in 1:nrow(portfolio_with_divs)) {
  row <- portfolio_with_divs[i, ]

  report_lines <- c(report_lines, paste0("TICKER: ", row$ticker))
  report_lines <- c(report_lines, strrep("-", 80))
  report_lines <- c(report_lines, paste0("  First Purchase:        ", format(row$first_purchase, "%Y-%m-%d")))
  report_lines <- c(report_lines, paste0("  Months Held:           ", round(row$months_held, 1)))
  report_lines <- c(report_lines, paste0("  Quantity:              ", row$qtde_total))
  report_lines <- c(report_lines, paste0("  Total Invested:        R$ ", format(row$invested, big.mark = ",", nsmall = 2)))
  report_lines <- c(report_lines, paste0("  Current Price:         R$ ", format(row$current_price, nsmall = 2)))
  report_lines <- c(report_lines, paste0("  Current Value:         R$ ", format(row$current_value, big.mark = ",", nsmall = 2)))
  report_lines <- c(report_lines, "")
  report_lines <- c(report_lines, "  DIVIDENDS:")
  report_lines <- c(report_lines, paste0("    Actual payments:     ", row$div_count, " payments"))
  report_lines <- c(report_lines, paste0("    Actual dividends:    R$ ", format(row$div_total, big.mark = ",", nsmall = 2)))

  if (!is.na(row$last_div_date)) {
    report_lines <- c(report_lines, paste0("    Last payment:        ", format(row$last_div_date, "%Y-%m-%d")))
  }

  if (row$missing_months > 0) {
    report_lines <- c(report_lines, paste0("    Missing months:      ", round(row$missing_months, 0)))
    report_lines <- c(report_lines, paste0("    Estimated missing:   R$ ", format(row$estimated_missing_div, big.mark = ",", nsmall = 2)))
    report_lines <- c(report_lines, paste0("    DY 12M (reference):  ", format(row$dy_12m, nsmall = 2), "%"))
  }

  report_lines <- c(report_lines, paste0("    TOTAL DIVIDENDS:     R$ ", format(row$total_dividends, big.mark = ",", nsmall = 2)))
  report_lines <- c(report_lines, "")
  report_lines <- c(report_lines, "  RETURNS:")
  report_lines <- c(report_lines, paste0("    Without dividends:   ", format(row$return_without_div * 100, nsmall = 2), "%"))
  report_lines <- c(report_lines, paste0("    With dividends:      ", format(row$return_with_div * 100, nsmall = 2), "%"))
  report_lines <- c(report_lines, paste0("    Div yield on cost:   ", format(row$div_yield_on_cost * 100, nsmall = 2), "%"))
  report_lines <- c(report_lines, "")
  report_lines <- c(report_lines, "")
}

# 6. Portfolio totals
total_invested <- sum(portfolio_with_divs$invested, na.rm = TRUE)
total_current_value <- sum(portfolio_with_divs$current_value, na.rm = TRUE)
total_dividends_actual <- sum(portfolio_with_divs$div_total, na.rm = TRUE)
total_dividends_estimated <- sum(portfolio_with_divs$estimated_missing_div, na.rm = TRUE)
total_dividends_all <- sum(portfolio_with_divs$total_dividends, na.rm = TRUE)

portfolio_return_no_div <- (total_current_value - total_invested) / total_invested
portfolio_return_with_div <- (total_current_value + total_dividends_all - total_invested) / total_invested

report_lines <- c(report_lines, strrep("=", 80))
report_lines <- c(report_lines, "PORTFOLIO TOTALS")
report_lines <- c(report_lines, strrep("=", 80))
report_lines <- c(report_lines, "")
report_lines <- c(report_lines, paste0("Total Invested:                R$ ", format(total_invested, big.mark = ",", nsmall = 2)))
report_lines <- c(report_lines, paste0("Current Value:                 R$ ", format(total_current_value, big.mark = ",", nsmall = 2)))
report_lines <- c(report_lines, paste0("Actual Dividends Received:     R$ ", format(total_dividends_actual, big.mark = ",", nsmall = 2)))
report_lines <- c(report_lines, paste0("Estimated Missing Dividends:   R$ ", format(total_dividends_estimated, big.mark = ",", nsmall = 2)))
report_lines <- c(report_lines, paste0("TOTAL DIVIDENDS:               R$ ", format(total_dividends_all, big.mark = ",", nsmall = 2)))
report_lines <- c(report_lines, "")
report_lines <- c(report_lines, paste0("Return WITHOUT Dividends:      ", format(portfolio_return_no_div * 100, nsmall = 2), "%"))
report_lines <- c(report_lines, paste0("Return WITH Dividends:         ", format(portfolio_return_with_div * 100, nsmall = 2), "%"))
report_lines <- c(report_lines, paste0("Dividend Impact:               ", format((portfolio_return_with_div - portfolio_return_no_div) * 100, nsmall = 2), "% points"))
report_lines <- c(report_lines, "")
report_lines <- c(report_lines, strrep("=", 80))

# Write report to file
writeLines(report_lines, "/tmp/portfolio_with_dividends.txt")

# Print summary to console
cat("\n=== PORTFOLIO SUMMARY ===\n\n")
cat("Total Invested:              R$", format(total_invested, big.mark = ",", nsmall = 2), "\n")
cat("Current Value:               R$", format(total_current_value, big.mark = ",", nsmall = 2), "\n")
cat("Actual Dividends Received:   R$", format(total_dividends_actual, big.mark = ",", nsmall = 2), "\n")
cat("Estimated Missing Dividends: R$", format(total_dividends_estimated, big.mark = ",", nsmall = 2), "\n")
cat("TOTAL DIVIDENDS:             R$", format(total_dividends_all, big.mark = ",", nsmall = 2), "\n\n")

cat("Return WITHOUT Dividends:    ", format(portfolio_return_no_div * 100, nsmall = 2), "%\n")
cat("Return WITH Dividends:       ", format(portfolio_return_with_div * 100, nsmall = 2), "%\n")
cat("Dividend Impact:             +", format((portfolio_return_with_div - portfolio_return_no_div) * 100, nsmall = 2), "% points\n\n")

cat("Detailed report saved to: /tmp/portfolio_with_dividends.txt\n\n")

# Also create a CSV for further analysis
portfolio_with_divs %>%
  select(
    ticker,
    first_purchase,
    months_held,
    qtde_total,
    invested,
    current_price,
    current_value,
    div_count,
    div_total,
    missing_months,
    estimated_missing_div,
    total_dividends,
    return_without_div,
    return_with_div,
    div_yield_on_cost
  ) %>%
  write_csv("/tmp/portfolio_with_dividends.csv")

cat("CSV data saved to: /tmp/portfolio_with_dividends.csv\n")
