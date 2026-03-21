# CVM Collector Documentation

## Overview

The CVM (Comissão de Valores Mobiliários) collector imports official monthly reports from Brazilian Real Estate Investment Funds (FIIs). This data source is authoritative, free, and does not require authentication.

## Data Source

- **URL**: https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/
- **Format**: CSV (semicolon-delimited, Windows-1252 encoding)
- **Update Frequency**: Monthly (with ~2 week delay)
- **Access**: Public, no authentication required
- **Data Structure**: Multiple CSV files per year in ZIP archives

## Available Data

The collector extracts the following indicators:

### Core Metrics
- `patrimonio_liquido` - Net equity (Patrimônio Líquido)
- `valor_patrimonial_cota` - Net Asset Value per share (Valor Patrimonial por Cota)
- `dividend_yield` - Monthly Dividend Yield (%)
- `rentabilidade_mensal` - Monthly return (%)
- `numero_cotistas` - Number of shareholders

### Fund Information
- `nome_fundo` - Fund name
- `segmento` - Market segment (e.g., "Logística", "Lajes Corporativas")

### Fee Structure (when available)
- `tx_administracao` - Administration fee
- `tx_performance` - Performance fee

## Data NOT Available

The CVM monthly reports do **not** include:
- **Vacancy rates** (VACÂNCIA) - Use StatusInvest for this metric
- Detailed property information
- Intraday price quotes
- Historical price series

## Architecture

### File Structure

```
R/import/fii_cvm_data.R              # Main collector implementation
R/_draft/test_cvm_collector.R        # Test suite
R/_draft/example_cvm_collector_usage.R  # Usage examples
```

### Key Components

1. **create_cvm_collector()** - Factory function following collector_base.R pattern
2. **fetch_cvm_monthly_data()** - Downloads and parses CSV files for a year
3. **extract_fii_indicators()** - Filters and transforms data for portfolio FIIs
4. **build_cnpj_ticker_mapping()** - Creates/loads CNPJ↔ticker mapping table
5. **get_fii_cvm_history()** - Convenience function for retrieving ticker history

### Data Flow

```
1. Portfolio Tickers
   ↓
2. CNPJ Mapping (ticker → CNPJ)
   ↓
3. Download CVM ZIP files (cached)
   ↓
4. Parse CSV files (geral + complemento)
   ↓
5. Filter by portfolio CNPJs
   ↓
6. Extract indicators
   ↓
7. Merge with existing data (incremental)
   ↓
8. Save to fii_cvm.rds
```

## Configuration

### Standard Config

```r
config <- list(
  base_url = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/",
  cache_dir = "data/.cache/cvm",
  cache_ttl_days = 30,
  data = list(
    portfolio_file = "data/portfolio.rds"
  ),
  output = "fii_cvm.rds"
)
```

### Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `base_url` | CVM URL | Base URL for data downloads |
| `cache_dir` | `data/.cache/cvm` | Directory for cached ZIP/CSV files |
| `cache_ttl_days` | 30 | Cache validity in days (monthly data) |
| `data.portfolio_file` | `data/portfolio.rds` | Portfolio file for ticker list |
| `output` | `fii_cvm.rds` | Output filename in data/ directory |

## Caching Strategy

The collector implements intelligent caching to minimize downloads:

1. **ZIP Files**: Cached for `cache_ttl_days` (default: 30 days)
2. **Extracted CSVs**: Kept in cache directory for reuse
3. **CNPJ Mapping**: Cached for 90 days in `data/fii_cnpj_mapping.rds`

Cache invalidation occurs when:
- TTL expires
- File doesn't exist
- Manual deletion of cache files

## CNPJ-Ticker Mapping

The CVM uses CNPJ (Brazilian corporate tax ID) as the primary identifier, not ticker symbols. The collector maintains a mapping table from multiple sources:

### Mapping Sources (in priority order)

1. **fii_info.rds** - If available and contains CNPJ field
2. **fii_lupa.rds** - From Lupa de FIIs collector
3. **Hardcoded mappings** - Known CNPJs from validation (KNRI11, MXRF11, VISC11)

### Building/Updating Mapping

The mapping is automatically built on first use and cached for 90 days. To force rebuild:

```r
# Delete cached mapping
file.remove("data/fii_cnpj_mapping.rds")

# Rebuild on next collector run
logger <- create_logger(level = "INFO")
mapping <- build_cnpj_ticker_mapping(logger)
```

### Coverage

Not all FII tickers will have CNPJ mappings immediately. The collector gracefully handles this by:
- Logging which tickers have mappings
- Only collecting data for tickers with known CNPJs
- Reporting missing mappings in metadata

To improve coverage:
1. Add CNPJs to `fii_info.rds` or `fii_lupa.rds`
2. Add hardcoded mappings in `build_cnpj_ticker_mapping()`
3. Use StatusInvest or other sources to discover CNPJs

## Usage Examples

### Basic Collection

```r
source("R/import/fii_cvm_data.R")
source("R/utils/logging.R")

logger <- create_logger(level = "INFO")

config <- list(
  cache_dir = "data/.cache/cvm",
  cache_ttl_days = 30,
  data = list(portfolio_file = "data/portfolio.rds"),
  output = "fii_cvm.rds"
)

collector <- create_cvm_collector(config, logger)
result <- collector$collect()

if (result$success) {
  cat("✓ Collected", result$metadata$rows, "rows\n")
}
```

### Retrieve Historical Data

```r
# Get 12 months of history for a FII
history <- get_fii_cvm_history("KNRI11", months = 12)

# Calculate average DY
mean_dy <- mean(history$dividend_yield, na.rm = TRUE)
```

### Pipeline Integration

```r
# In pipeline/main_complete_pipeline.R
collectors <- list(
  portfolio = create_portfolio_collector(config$collectors$portfolio, logger),
  prices = create_prices_collector(config$collectors$prices, logger),
  cvm = create_cvm_collector(config$collectors$cvm, logger)
)

results <- list()
for (name in names(collectors)) {
  results[[name]] <- collectors[[name]]$collect()
}
```

## Output Schema

The collector saves data to `data/fii_cvm.rds` with the following schema:

| Column | Type | Description |
|--------|------|-------------|
| `ticker` | character | FII ticker (e.g., "ALZR11") |
| `data_competencia` | Date | Reference date (YYYY-MM-DD) |
| `nome_fundo` | character | Fund name |
| `segmento` | character | Market segment |
| `patrimonio_liquido` | numeric | Net equity (R$) |
| `valor_patrimonial_cota` | numeric | NAV per share (R$) |
| `dividend_yield` | numeric | Monthly DY (%) |
| `rentabilidade_mensal` | numeric | Monthly return (%) |
| `numero_cotistas` | numeric | Number of shareholders |
| `tx_administracao` | numeric | Admin fee (%) |
| `tx_performance` | numeric | Performance fee (%) |

## Error Handling

The collector implements robust error handling:

### Download Failures
- **Retry**: 3 attempts with exponential backoff (2x factor)
- **Circuit Breaker**: Opens after 5 consecutive failures
- **Fallback**: Uses cached data if available

### Parse Errors
- **Encoding**: Handles Windows-1252 encoding automatically
- **Missing Files**: Logs warning and continues with available data
- **Invalid Data**: Logs error, skips problematic records

### Collection Failures
- Returns `result$success = FALSE` with error message
- Logs detailed error information
- Does not interrupt pipeline execution

## Performance

Typical collection performance:

- **First run** (no cache): 10-30 seconds (depends on network)
  - Download: ~2-5 MB per year
  - Parse: ~1-2 seconds per CSV
  - Extract: <1 second

- **Cached run**: 1-3 seconds
  - Download: skipped
  - Parse: cached CSVs
  - Extract: <1 second

## Testing

### Run Test Suite

```bash
cd /Users/gsposito/Projects/fii_manager
Rscript R/_draft/test_cvm_collector.R
```

### Test Coverage

1. **test_cnpj_mapping()** - Validates mapping table creation
2. **test_download_and_parse()** - Tests data download and CSV parsing
3. **test_extract_indicators()** - Tests indicator extraction logic
4. **test_full_collector()** - Integration test of full collector
5. **test_get_history()** - Tests historical data retrieval

### Expected Results

- All tests should pass (5/5)
- First run will download ~2-5 MB of data
- Subsequent runs use cache and complete in 1-3 seconds

## Troubleshooting

### No Data Collected

**Symptom**: `result$metadata$tickers_success = 0`

**Causes**:
1. No CNPJ mappings for portfolio tickers
2. Portfolio file not found
3. Network issues

**Solutions**:
- Check `result$metadata$failed_tickers` for missing mappings
- Verify `data/portfolio.rds` exists
- Run `build_cnpj_ticker_mapping()` to inspect available mappings

### Download Failures

**Symptom**: "Failed to download" errors

**Causes**:
1. Network connectivity issues
2. CVM server downtime
3. Firewall blocking requests

**Solutions**:
- Check internet connection
- Verify CVM URL is accessible: https://dados.cvm.gov.br/
- Check firewall/proxy settings
- Wait and retry (collector has automatic retry with backoff)

### Parse Errors

**Symptom**: "Failed to read CSV" errors

**Causes**:
1. Corrupted ZIP download
2. CVM changed CSV format
3. Encoding issues

**Solutions**:
- Delete cache: `rm -rf data/.cache/cvm`
- Re-download data
- Check CVM website for format changes
- Verify CSV encoding is Windows-1252

### Memory Issues

**Symptom**: R crashes or "out of memory" errors

**Causes**:
1. Processing multiple years of data
2. Large portfolio (many tickers)
3. Insufficient system RAM

**Solutions**:
- Reduce years processed (modify `years <- c(current_year)`)
- Clear R environment: `rm(list = ls()); gc()`
- Increase R memory limit: `memory.limit(size = 8000)` (Windows)

## Best Practices

1. **Cache Management**: Don't delete cache unnecessarily - it saves time and bandwidth
2. **CNPJ Mapping**: Keep `fii_info.rds` updated with CNPJs for new FIIs
3. **Incremental Updates**: Run collector monthly (aligns with CVM update frequency)
4. **Validation**: Check `result$metadata$failed_tickers` and investigate missing mappings
5. **Logging**: Use structured logging in production pipelines

## Integration with Other Collectors

The CVM collector complements other data sources:

| Metric | CVM | StatusInvest | Yahoo Finance |
|--------|-----|--------------|---------------|
| Price quotes | ❌ | ❌ | ✅ |
| NAV per share | ✅ | ✅ | ❌ |
| Dividend Yield | ✅ | ✅ | ❌ |
| Vacancy | ❌ | ✅ | ❌ |
| Shareholders | ✅ | ❌ | ❌ |
| Segment | ✅ | ✅ | ❌ |

**Recommended strategy**: Use CVM as primary source for official fund metrics, supplement with StatusInvest for vacancy and additional indicators.

## Future Enhancements

Potential improvements:

1. **Automatic CNPJ Discovery**: Scrape StatusInvest to build complete CNPJ mapping
2. **Historical Backfill**: Download multiple years on first run
3. **Data Validation**: Implement validator (R/validators/cvm_validator.R)
4. **Additional Metrics**: Extract more fields from CVM reports (asset breakdown, etc.)
5. **Delta Updates**: Only process new months instead of full year

## References

- CVM Open Data Portal: https://dados.cvm.gov.br/
- FII Monthly Reports: https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/
- CVM Documentation: https://dados.cvm.gov.br/dataset/fii-doc-inf_mensal
