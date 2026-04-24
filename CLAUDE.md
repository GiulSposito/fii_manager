# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

R-based portfolio management system for Brazilian Real Estate Investment Funds (FIIs). Handles data import, analysis, scoring, and reporting for a personal portfolio of ~60 FIIs.

## Architecture

### Pipeline v3.0 (Current)

The main entry point is `R/pipeline/main_complete_pipeline.R`, which orchestrates 7 phases:

1. **IMPORT** — `hybrid_pipeline_run()` coordinates all collectors by priority; CVM data via `fii_cvm_data.R`
2. **CLEAN** — validates core RDS files and cross-validates CVM data via `R/validators/`
3. **TRANSFORM** — `run_scoring_pipeline()` computes 11 indicators across 4 blocks (see below)
4. **DEEP** — `enrich_scores_with_deep_indicators()` adds leverage, momentum, z-scores from CVM data
5. **PERSIST** — saves `data/fii_scores_enriched.rds` + CSV export + backups in `data_backup/`
6. **ANALYSIS** — optional per-ticker deep analysis via `R/analysis/fii_individual_analysis.R`
7. **REPORT** — optional markdown reports written to `reports/YYYY-MM-DD/`

```r
source("R/pipeline/main_complete_pipeline.R")

# Full refresh
result <- run_complete_analysis(mode = "full")

# Incremental, portfolio tickers only
result <- run_complete_analysis(mode = "incremental", tickers = "portfolio")

# Specific tickers with reports
result <- run_complete_analysis(
  tickers = c("KNRI11", "MXRF11"),
  include_analysis = TRUE,
  include_reports = TRUE
)
```

### Collector Pattern

All data collectors in `R/collectors/` follow a shared base pattern from `collector_base.R`:

```r
collector <- create_base_collector(name, config, logger, collect_fn)
result <- collector$collect()  # Returns list(success, data, error, metadata)
```

Available collectors: `portfolio_collector.R`, `statusinvest_income_collector.R`, `statusinvest_indicators_collector.R`, `fiiscom_lupa_collector.R`, `yahoo_prices_collector.R`.

The hybrid pipeline (`R/pipeline/hybrid_pipeline.R`) coordinates them using `config/pipeline_config.yaml`.

### 4-Block Scoring Framework (`R/transform/`)

- **Block A — Quality** (25%): concentration score, quality_score_basic
- **Block B — Income** (30%): DY 12m (40%), dividend stability (30%), consistency (30%)
- **Block C — Valuation** (25%): P/VP ratio
- **Block D — Risk** (20%): liquidity, volatility metrics

`fii_scoring.R` computes per-block scores → `fii_score_pipeline.R` orchestrates → `fii_deep_indicators.R` enriches with CVM-derived leverage, momentum, and z-scores.

### Utility Layer (`R/utils/`)

| File | Purpose |
|------|---------|
| `logging.R` | `create_logger()` / `setup_logging()` — structured or simple format, file+console output |
| `persistence.R` | RDS read/write helpers with cache TTL |
| `http_client.R` | Retry-aware HTTP GET/POST with user-agent "fiiscrapeR" |
| `brazilian_parsers.R` | `parse_br_number()`, `parse_br_date()`, `parse_br_ticker()`, `parse_br_percent()` |
| `ticker_utils.R` | Ticker normalization; Yahoo Finance requires `.SA` suffix (e.g., `HGLG11.SA`) |

### Data Files (`data/`, gitignored)

All files share `ticker` as the join key. Tickers are uppercase strings (e.g., `HGLG11`).

| File | Contents | Key fields |
|------|----------|-----------|
| `portfolio.rds` | Buy/sell transactions | `date`, `ticker`, `volume`, `price`, `taxes`, `value`, `portfolio` |
| `quotations.rds` | Historical prices | `ticker`, `price`, `date` |
| `income.rds` | Dividend distributions | `ticker`, `rendimento`, `data_base`, `data_pagamento`, `cota_base`, `dy` |
| `fiis.rds` | FII metadata from Lupa | `ticker`, `tipo_fii`, `patrimonio`, `rendimento_12m`, `dy`, `cota_vp`, … |
| `fii_cvm.rds` | CVM fundamental data | `ticker`, `data_competencia`, `patrimonio_liquido`, `ativo_total`, … |
| `fii_scores.rds` | Basic scores | Per-ticker scored indicators |
| `fii_scores_enriched.rds` | Full scores + deep indicators | Primary output of pipeline |

Monetary values are in BRL (numeric double). Percentages stored as decimals (0.0523 = 5.23%). Dates as R `Date` objects (ISO format).

## Running Tests

```r
# Individual test file (uses testthat, run from project root)
source("tests/test_parsers.R")
source("tests/test_integration.R")
source("tests/test_pipeline_v3_e2e.R")
```

## Configuration

`config/pipeline_config.yaml` controls all data sources, execution mode, cache TTL, logging, and fallback behavior. Key settings:

- `execution.mode`: `"incremental"` (default) or `"full_refresh"`
- `data_sources.*.enabled`: toggle individual collectors
- `logging.level`: `DEBUG` | `INFO` | `WARN` | `ERROR`

## Environment Variables

The fiis.com.br Lupa API collector requires:
- `FIISCOM_COOKIE` — session cookie for authentication
- `FIISCOM_NONCE` — WordPress nonce token

## Key Implementation Details

### Brazilian Number Parsing

Always use the shared utility instead of inline parsing:
```r
# Correct: use R/utils/brazilian_parsers.R
parse_br_number("1.234,56")  # → 1234.56
parse_br_percent("8,5%")      # → 0.085 (as decimal)
parse_br_date("15/03/2026")   # → 2026-03-15
```

### Incremental Updates

Income distributions (`income.rds`) are updated incrementally: new rows appended with `bind_rows()`, deduped with `distinct()`. Manual corrections live in `R/import/fixProventos.R` (`fixProventos()`).

### Web Scraping Constraints

fiis.com.br scraping (legacy path, `R/import/proventos.R`) requires `Sys.sleep(180)` between tickers and `gc()` before sleeping to close connections. The newer `statusinvest_income_collector.R` avoids this by using a batch API endpoint.

### Lupa de FIIs CSRF

The CSRF token must be extracted from the initial GET response headers and passed as `X-XSRF-TOKEN` on subsequent POST requests.

## Directory Structure

```
R/
├── _archived/       # Old pipelines (pre-v3), do not use
├── _draft/          # Experimental / WIP scripts
├── _examples/       # Runnable usage examples
├── analysis/        # Standalone analysis scripts (source directly)
├── api/             # Older direct API clients (largely superseded by collectors/)
├── collectors/      # Modular data collectors (current pattern)
├── import/          # Legacy importers and fixProventos
├── pipeline/        # Pipeline orchestrators (main_complete_pipeline.R is current)
├── reports/         # Report generation helpers
├── transform/       # Scoring, indicators, deep indicators
├── utils/           # Shared utilities (logging, parsers, http, persistence)
└── validators/      # Schema, data quality, CVM, consistency validators
config/
└── pipeline_config.yaml   # Central pipeline configuration
tests/                     # testthat test files
import/                    # Raw import files (broker statements, CSVs)
```

## Code Style

- tidyverse conventions throughout; prefer `|>` in new code, `%>%` in existing code
- Function names: camelCase for public (e.g., `updatePortfolio`), `.camelCase` for private helpers
- Collectors return `list(success, data, error, metadata)` via `create_result()`
- Loggers created with `create_logger()` or `setup_logging(config)`; use `logger$info()`, `logger$warn()`, `logger$error()`
- 2-space indentation
