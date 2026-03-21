# Transform Layer - FII Scoring Pipeline

**Purpose:** Calculate FII scores as part of the data pipeline (after import, before analysis)

**Architecture:** Import → **Transform (scores)** → Analysis

---

## 📋 Overview

The transform layer calculates multi-factor scores for all FIIs and saves them as structured data for fast analysis consumption.

### Why Transform Layer?

**Before (incorrect):**
```
Import → raw data
           ↓
Analysis → calculate scores on-demand (slow, repetitive)
```

**After (correct):**
```
Import → raw data (portfolio, quotes, income, fiis)
           ↓
Transform → data/fii_scores.rds (pre-calculated) ← THIS LAYER
           ↓
Analysis → instant queries (0.1s vs 2min)
```

**Benefits:**
- ✅ Scores calculated once, used many times
- ✅ Historical tracking (score changes over time)
- ✅ Clean architecture (separation of concerns)
- ✅ Fast analysis (read vs calculate)
- ✅ Cacheable and versionable

---

## 📁 Files

```
R/transform/
├── fii_data_sources.R      # Data consolidation
├── fii_indicators.R        # Indicator calculations
├── fii_scoring.R           # Scoring engine
├── fii_score_pipeline.R    # Pipeline orchestration ← MAIN
└── README.md               # This file
```

---

## 🚀 Usage

### As Part of Main Pipeline

```r
# Run complete pipeline (import + transform)
source("R/pipeline/main_portfolio_with_scoring.R")
```

This will:
1. Import all data (portfolio, quotes, income, market data)
2. Calculate scores for all FIIs
3. Save to `data/fii_scores.rds`
4. Append to `data/fii_scores_history.rds`

### Standalone Scoring

```r
# Run just the scoring pipeline (if data already imported)
source("R/transform/fii_score_pipeline.R")
scores <- run_scoring_pipeline()
```

### Incremental Update

```r
# Update scores for specific tickers only
source("R/transform/fii_score_pipeline.R")
update_scores_incremental(c("HGLG11", "KNRI11"))
```

---

## 📊 Output Files

### `data/fii_scores.rds` (Main Output)

**Schema:**
```r
# A tibble: 538 × 15
  ticker tipo_fii           total_score quality income valuation risk
  <chr>  <chr>                    <dbl>   <dbl>  <dbl>     <dbl> <dbl>
  HGLG11 Tijolo:Logística          33.5    72.1   21.8      15.9  25.0
  ...

# Additional columns:
  dy_12m pvp current_price recommendation data_completeness
  <dbl> <dbl>        <dbl> <chr>                      <dbl>
    4.08 0.994        161.79 EVITAR                      0.75

# Metadata:
  calculated_at       data_version pipeline_version
  <dttm>             <chr>        <chr>
  2026-03-20 17:30   20260320     1.0.0
```

**Usage:**
```r
scores <- readRDS("data/fii_scores.rds")

# Or using helper
source("R/transform/fii_score_pipeline.R")
scores <- load_scores()
```

### `data/fii_scores_history.rds` (Historical Tracking)

Keeps last 30 days of scores per ticker for change tracking.

**Usage:**
```r
history <- readRDS("data/fii_scores_history.rds")

# Get history for one FII
history %>%
  filter(ticker == "HGLG11") %>%
  arrange(calculated_at)
```

### `data/fii_scores.csv` (Export)

CSV version for external tools (Excel, BI tools, etc.)

---

## 🔧 Configuration

### Pipeline Parameters

```r
run_scoring_pipeline(
  tickers = "all",                # "all" or vector of tickers
  include_statusinvest = FALSE,   # Fetch external data (slower)
  force = FALSE                   # Force recalc even if recent
)
```

### Scoring Weights

Default: Quality 25%, Income 30%, Valuation 25%, Risk 20%

To customize, modify in `R/transform/fii_scoring.R`:
```r
calculate_fii_score(
  ticker,
  weights = c(quality = 0.20, income = 0.40, valuation = 0.25, risk = 0.15)
)
```

---

## ⚡ Performance

| Operation | Time | Notes |
|-----------|------|-------|
| Full pipeline (60 FIIs) | 1-2 min | Initial calculation |
| Incremental (1 FII) | 1-2 s | Single update |
| Load scores | 0.1 s | Read from disk |
| Analysis queries | 0.1-1 s | Using pre-calculated scores |

**Memory:** ~100-200MB during pipeline

---

## 🔄 Pipeline Integration

### New Main Pipeline

```r
# R/pipeline/main_portfolio_with_scoring.R

# PHASE 1: Import
source("R/import/portfolioGoogleSheets.R")
portfolio <- updatePortfolio()

source("R/import/pricesYahoo.R")
prices <- updatePortfolioPrices(portfolio)

source("R/import/proventos.R")
proventos <- updateProventos(portfolio)

# PHASE 2: Transform (NEW!)
source("R/transform/fii_score_pipeline.R")
scores <- run_scoring_pipeline()

# PHASE 3: Analysis (uses scores)
source("R/analysis/fii_analysis.R")
portfolio_summary()
```

### Backward Compatibility

Old scripts in `R/analysis/` still work (calculate on-demand).
New scripts read pre-calculated scores (recommended).

---

## 📚 Functions Reference

### `fii_score_pipeline.R`

| Function | Purpose |
|----------|---------|
| `run_scoring_pipeline()` | Main pipeline function |
| `update_scores_incremental(tickers)` | Update specific tickers |
| `need_score_refresh(max_age_hours)` | Check if refresh needed |
| `load_scores(auto_refresh)` | Load with optional auto-refresh |
| `get_score_history(ticker)` | Historical scores for ticker |
| `detect_score_changes(min_change)` | Find significant changes |

### `fii_data_sources.R`

| Function | Purpose |
|----------|---------|
| `load_cached_data()` | Load all RDS files |
| `get_fii_data(ticker)` | Consolidated data for ticker |
| `get_comprehensive_fii_data(ticker)` | All sources |
| `validate_fii_data(fii_data)` | Data quality check |

### `fii_indicators.R`

11 indicator calculation functions (see main README)

### `fii_scoring.R`

| Function | Purpose |
|----------|---------|
| `calculate_fii_score(ticker)` | Core scoring |
| `calculate_*_block()` | Individual block scores |
| `score_multiple_fiis(tickers)` | Batch scoring |

---

## 🔍 Monitoring & Debugging

### Check Score Freshness

```r
source("R/transform/fii_score_pipeline.R")

if (need_score_refresh(max_age_hours = 24)) {
  message("Scores are stale, refreshing...")
  run_scoring_pipeline()
}
```

### Validate Pipeline Output

```r
scores <- readRDS("data/fii_scores.rds")

# Check completeness
mean(scores$data_completeness, na.rm = TRUE)  # Should be > 0.75

# Check age
max(scores$calculated_at, na.rm = TRUE)  # Should be recent

# Check coverage
nrow(scores)  # Should match number of active FIIs
```

---

## 📝 Maintenance

### Daily/Weekly Schedule

Recommended cron job:
```bash
# Daily at 7pm (after market close)
0 19 * * * Rscript -e "source('R/pipeline/main_portfolio_with_scoring.R')"
```

### Manual Refresh

```r
# Force refresh
source("R/transform/fii_score_pipeline.R")
run_scoring_pipeline(force = TRUE)
```

### Cleanup Old History

```r
# Keep only last 30 days
history <- readRDS("data/fii_scores_history.rds")
history <- history %>%
  filter(calculated_at >= today() - days(30))
saveRDS(history, "data/fii_scores_history.rds")
```

---

## ✅ Validation Checklist

Before using analysis scripts, verify:

- [ ] `data/fii_scores.rds` exists
- [ ] Scores are recent (< 24h old)
- [ ] Data completeness > 75%
- [ ] All portfolio tickers have scores

```r
# Quick validation
source("R/transform/fii_score_pipeline.R")
scores <- load_scores()

# Checks
file.exists("data/fii_scores.rds")  # TRUE
max(scores$calculated_at) > Sys.time() - hours(24)  # TRUE
mean(scores$data_completeness) > 0.75  # TRUE
```

---

**Last Updated:** 2026-03-20
**Version:** 1.0.0
**Status:** ✅ Production Ready
