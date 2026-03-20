# Phase 2: Main Collectors

This directory contains the core data collectors for the hybrid pipeline architecture.

## Overview

The collectors implement a standardized pattern for data acquisition from different sources. Each collector follows the same interface and integrates with the Phase 1 utilities (logging, HTTP client, parsers, persistence).

## Components

### 1. collector_base.R

Base collector pattern providing:
- Standard `collect()` method interface
- Error handling and recovery
- Execution tracking and statistics
- Integration with logger and config
- Result format standardization

**Key Functions:**
- `create_base_collector(name, config, logger, collect_fn)` - Creates a collector instance
- `create_result(success, data, error, metadata)` - Standard result format
- `validate_result(result, required_fields, logger)` - Result validation

**Standard Result Format:**
```r
list(
  success = TRUE/FALSE,
  data = tibble(...),    # NULL on failure
  error = NULL/character, # NULL on success
  rows = integer,
  metadata = list(...)
)
```

### 2. statusinvest_income_collector.R

**Critical Performance Improvement: 60x faster**

Collects FII income distributions from Status Invest API using a single batch request.

**Previous approach:** Individual scraping per ticker (slow, fragile)
**New approach:** Batch API call for all FIIs at once

**Features:**
- Batch GET request to `/fii/getearnings`
- IndiceCode=ifix fetches all FIIs
- Automatic date range handling
- Brazilian date/number parsing
- Incremental merge with existing data
- Deduplication by ticker + dates

**Schema Transformation:**
```r
# Status Invest API response:
code, resultAbsoluteValue, dateCom, paymentDividend, dy

# Transformed to income.rds schema:
ticker, rendimento, data_base, data_pagamento, cota_base, dy
```

**Usage:**
```r
collector <- create_statusinvest_income_collector(config, logger)
result <- collector$collect()
```

**Config Requirements:**
```yaml
api:
  statusinvest:
    base_url: https://statusinvest.com.br
    earnings_endpoint: /fii/getearnings
    income_start_date: "2024-01-01"  # Optional, defaults to 1 year ago

data:
  income_file: ./data/income.rds
  backup_dir: data_backup
```

### 3. portfolio_collector.R

Wraps existing Google Sheets portfolio import with the collector pattern.

**Features:**
- Reads from Google Sheets API
- Uses existing authentication
- Standard column mapping
- Local RDS caching with backup
- Validation of required fields

**Schema:**
```r
date, ticker, volume, price, taxes, value, portfolio
```

**Usage:**
```r
collector <- create_portfolio_collector(config, logger)
result <- collector$collect()
```

**Config Requirements:**
```yaml
data:
  portfolio:
    google_sheet_key: "1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU"
  portfolio_file: ./data/portfolio.rds
  backup_dir: data_backup
```

## Collector Pattern

All collectors follow this pattern:

1. **Initialization:** `create_*_collector(config, logger)`
2. **Collection:** `collector$collect()` returns standard result
3. **Statistics:** `collector$get_stats()` returns execution info

### Standard Interface

```r
collector <- create_*_collector(config, logger)

# Collect data
result <- collector$collect()

# Check result
if (result$success) {
  data <- result$data
  rows <- result$rows
  # Process data...
} else {
  error <- result$error
  # Handle error...
}

# Get statistics
stats <- collector$get_stats()
# Returns: name, run_count, last_run_time, last_run_success, last_run_error
```

## Integration with Phase 1 Utils

Collectors use all Phase 1 utilities:

- **logging.R** - Structured logging of all operations
- **http_client.R** - HTTP requests with retry and rate limiting
- **brazilian_parsers.R** - Parse BR numbers/dates/tickers
- **persistence.R** - Incremental save with backup and deduplication

## Error Handling

Collectors implement graceful error handling:

1. **Network errors** - Logged, returned in result.error
2. **Parse errors** - Invalid records filtered out, logged
3. **Schema errors** - Validation fails, logged with details
4. **File errors** - Backup recovery, atomic writes

All errors are:
- Logged with context
- Returned in standard result format
- Non-fatal (pipeline can continue)

## Testing

Use `example_collectors_usage.R` for testing:

```r
source("R/collectors/example_collectors_usage.R")

# Test portfolio collector
example_portfolio_collection()

# Test income collector (60x performance gain!)
example_income_collection()

# Test with YAML config
example_with_yaml_config()

# Test result validation
example_result_validation()
```

## Performance Comparison

### Status Invest Income Collection

**Old approach (fiis.com.br scraping):**
- 1 request per ticker
- 150 tickers × 2 seconds = 5 minutes
- Fragile HTML parsing
- Frequent failures

**New approach (Status Invest API):**
- 1 batch request for all tickers
- ~5 seconds total
- JSON parsing
- Reliable

**Result: 60x performance improvement**

## Phase 3: Complementary Collectors

### 4. fiiscom_lupa_collector.R

Collects comprehensive FII metadata from fiis.com.br Lupa API.

**Features:**
- POST request to Lupa API
- Auth via cookies + nonce (environment variables)
- 22 columns of FII metadata
- Cache fallback (7-day TTL)
- Graceful auth expiry handling
- Double JSON parse (API quirk)

**Schema:**
```r
id, post_id, ticker, dy, rendimento_medio_12m, patrimonio_cota,
cota_base, cota_vp, numero_cotista, data_pagamento, data_base,
negocios, participacao_ifix, patrimonio, last_dividend, collected_at
```

**Auth Setup:**
```bash
export FIISCOM_COOKIE="your_cookie_here"
export FIISCOM_NONCE="your_nonce_here"
```

**Usage:**
```r
result <- collect_fiiscom_lupa(config, logger, force_refresh = FALSE)
```

**Fallback Behavior:**
- If auth fails → tries cache (any age)
- If cache miss → fails gracefully
- Cache TTL: 7 days (configurable)

### 5. statusinvest_indicators_collector.R

Scrapes fundamental indicators from Status Invest via web scraping.

**Features:**
- Web scraping from statusinvest.com.br
- Rate limiting: 3 seconds between requests
- Extracts cotação + indicadores sections
- NEW schema for fii_indicators.rds
- Incremental updates (replaces only updated tickers)

**Extracted Indicators:**
```r
ticker, collected_at, valor_atual, min_52sem, max_52sem,
dividend_yield, valorizacao_12m, p_vp, valor_patrimonial,
vacancia, valor_caixa, liquidez, numero_cotistas
```

**Usage:**
```r
result <- collect_statusinvest_indicators(tickers, config, logger)
```

**Rate Limiting:**
- Conservative 3s delay between requests
- Protects against rate limiting
- Logs progress for long collections

### 6. yahoo_prices_collector.R

Collects historical price quotes from Yahoo Finance.

**Features:**
- Uses BatchGetSymbols package
- Automatic .SA suffix for Brazilian tickers
- Includes IFIX index
- Incremental merge preserves history
- Wrapper for existing pricesYahoo.R code

**Schema:**
```r
ticker, ref.date, price.open, price.high, price.low, price.close,
volume, price.adjusted, ret.adjusted.prices, ret.closing.prices
```

**Usage:**
```r
# Collect for specific tickers
result <- collect_yahoo_prices(tickers, first_date, config, logger)

# Update entire portfolio
result <- update_portfolio_prices(portfolio, config, logger)

# Ad-hoc query
prices <- get_tickers_price(c("ALZR11", "HGLG11"), logger = logger)
```

**Helper Functions:**
- `update_portfolio_prices()` - Extracts tickers from portfolio
- `get_tickers_price()` - Direct fetch without saving

## File Structure

```
R/collectors/
├── README.md                              # This file
├── collector_base.R                       # Base pattern (Phase 2)
├── portfolio_collector.R                  # Portfolio from Google Sheets (Phase 2)
├── statusinvest_income_collector.R        # Income from Status Invest API (Phase 2, 60x faster!)
├── fiiscom_lupa_collector.R               # Lupa API metadata (Phase 3)
├── statusinvest_indicators_collector.R    # Indicators scraping (Phase 3)
├── yahoo_prices_collector.R               # Yahoo Finance prices (Phase 3)
└── example_collectors_usage.R             # Usage examples
```

## Dependencies

Required packages:
- httr2 (HTTP requests)
- dplyr, tidyr (data manipulation)
- googlesheets4 (portfolio import)
- lubridate (date handling)
- glue (string formatting)

All Phase 1 utilities must be sourced before collectors.

## Notes

- Income collector is the highest impact change (60x performance)
- All collectors use incremental saves (preserves history)
- Deduplication prevents duplicate records
- Atomic writes prevent corruption
- Backups created automatically
- Google Sheets auth must be configured externally
