# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an R-based portfolio management system for Brazilian Real Estate Investment Funds (FIIs - Fundos de Investimento Imobiliário). The system handles data import, processing, analysis, and visualization of FII portfolios, quotations, and income distributions (proventos).

## Architecture

### Core Data Flow

The project follows a pipeline architecture with three main stages:

1. **Import** (`R/import/`) - Data acquisition from multiple sources
2. **Transform** (`R/transform/`) - Data cleaning and standardization
3. **Analysis** (`R/analysis/`) - Portfolio analytics and visualizations

### Key Components

**Portfolio Management:**
- Portfolio data is stored in Google Sheets and imported via `portfolioGoogleSheets.R`
- Local cache stored as RDS files in `data/` directory (excluded from git)
- Main portfolio pipeline: `R/pipeline/main_portfolio.R`

**Data Import Sources:**
- Google Sheets (portfolio positions)
- Yahoo Finance (price quotes via `pricesYahoo.R`)
- fiis.com.br (income distributions via web scraping in `proventos.R`)
- Lupa de FIIs API (market data via `import_lupa.R`)
- Broker statements (Nubank, XPI via specific importers)

**API Layer:**
- `R/api/standalone_fii_api.R` - Core HTTP client with GET/POST functions
- Custom S3 class `fiis_api` for API responses
- User-agent "fiiscrapeR" used for web scraping

**Data Files** (in `data/`, gitignored):
- `portfolio.rds` - Portfolio positions
- `fii_proventos.rds` - Income distributions history
- `quotations.rds` - Price quotes
- `income.rds` - Income data

### Directory Structure

```
R/
├── _draft/          # Experimental/work-in-progress scripts
├── analysis/        # Portfolio analysis and reports
├── api/             # External API integrations
├── dashboard/       # RMarkdown dashboards
├── import/          # Data importers
├── pipeline/        # Main pipeline orchestration
└── transform/       # Data transformation logic
```

## Common Commands

### Running the Main Portfolio Pipeline

```r
# From project root in R console
source("R/pipeline/main_portfolio.R")
```

This will:
1. Import portfolio from Google Sheets
2. Update price quotes from Yahoo Finance
3. Scrape income distributions from fiis.com.br
4. Apply corrections for splits and errors
5. Save updated data to local RDS files

### Individual Data Updates

```r
# Update portfolio only
source("R/import/portfolioGoogleSheets.R")
port <- updatePortfolio()

# Update prices
source("R/import/pricesYahoo.R")
prices <- updatePortfolioPrices(port)

# Update income distributions
source("R/import/proventos.R")
proventos_page <- scrapProventos(port$ticker)
proventos <- extractProvFromScrap(proventos_page)
```

### Analysis Scripts

Analysis scripts in `R/analysis/` are typically standalone and can be sourced directly:

```r
source("R/analysis/nova_analise_proventos.R")
source("R/analysis/retorno_portfolio.R")
```

### Dashboards

RMarkdown dashboards are in `R/dashboard/`:

```r
# Render in RStudio or with:
rmarkdown::render("R/dashboard/portfolio.Rmd")
rmarkdown::render("R/dashboard/fii_performance.Rmd")
```

## Important Implementation Details

### Web Scraping Patterns

**fiis.com.br scraping** uses `rvest`:
- Implements safe scraping with `possibly()` to handle failures
- Requires 180-second sleep between operations (`Sys.sleep(180)`)
- Always call `gc()` before sleep to close connections

**Lupa de FIIs API** requires CSRF token handling:
- Extract token from initial GET request headers
- Include token in subsequent POST requests as `X-XSRF-TOKEN`
- Must set proper user-agent header for API access

### Data Type Parsing

Brazilian number format (comma as decimal separator):
```r
parse_number(x, locale=locale(grouping_mark=".", decimal_mark=","))
```

Date parsing uses `lubridate::dmy()` for Brazilian format (DD/MM/YYYY).

### Income Distribution Corrections

The `fixProventos()` function in `R/import/fixProventos.R` handles:
- Split adjustments
- Duplicate removal
- Manual corrections for known data quality issues

Updates are incremental - new data is appended with `bind_rows()` and deduplicated with `distinct()`.

### Google Sheets Authentication

Portfolio is stored in Google Sheet with key: `1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU`

Uses `googlesheets4` package (newer scripts) or `googlesheets` (older scripts).

## Code Style

- Use tidyverse conventions throughout
- Function names use camelCase (e.g., `updatePortfolio`, `scrapProventos`)
- Private helper functions prefixed with `.` (e.g., `.parseRealValue`)
- Pipeline operator: older code uses `%>%`, newer code may use `|>`
- 2-space indentation (per .Rproj settings)

## Key Dependencies

Core packages:
- tidyverse (dplyr, tidyr, purrr, stringr, ggplot2)
- lubridate (date handling)
- rvest (web scraping)
- httr/httr2 (HTTP requests)
- googlesheets4 (Google Sheets integration)
- jsonlite (JSON parsing)
- plotly (interactive visualizations)

## Data Privacy Note

The `data/` directory is gitignored and contains sensitive portfolio information. Never commit actual portfolio positions or personal financial data.
