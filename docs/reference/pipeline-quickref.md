# Pipeline v3.0 - Quick Reference Card

## One-Line Commands

```r
source("R/pipeline/main_complete_pipeline.R")

# 📊 Daily Update (2-5 min)
result <- run_complete_analysis(mode="incremental", tickers="portfolio", include_cvm=FALSE, include_deep_indicators=TRUE)

# 🔄 Weekly Refresh (10-20 min)
result <- run_complete_analysis(mode="full", tickers="all", include_cvm=FALSE, include_deep_indicators=TRUE)

# 🌙 Monthly Deep (30+ min)
result <- run_complete_analysis(mode="full", tickers="all", include_cvm=TRUE, include_deep_indicators=TRUE, include_analysis=TRUE, include_reports=TRUE)

# 🎯 Custom FIIs (1-5 min)
result <- run_complete_analysis(mode="incremental", tickers=c("KNRI11","MXRF11"), include_cvm=TRUE, include_deep_indicators=TRUE, include_analysis=TRUE, include_reports=TRUE)
```

## 7 Phases

| Phase | Name | Time | Output |
|-------|------|------|--------|
| 1 | IMPORT | 2-5 min | data/*.rds (raw) |
| 2 | CLEAN | <1 min | validation logs |
| 3 | TRANSFORM | 1-2 min | fii_scores.rds |
| 4 | DEEP | 1-3 min | fii_scores_enriched.rds |
| 5 | PERSIST | <1 min | backups, CSV |
| 6 | ANALYSIS | 5-20 min | fii_analyses_*.rds |
| 7 | REPORT | 1-5 min | reports/*.md |

## Parameters Cheat Sheet

```r
run_complete_analysis(
  mode                    # "full" or "incremental"
  tickers                 # "all", "portfolio", or c("KNRI11", ...)
  include_cvm             # TRUE = collect CVM (monthly)
  include_deep_indicators # TRUE = advanced metrics
  include_analysis        # TRUE = individual FII analysis (slow)
  include_reports         # TRUE = markdown reports
  log_level               # "DEBUG", "INFO", "WARN", "ERROR"
)
```

## Output Files

```
data/
├── fii_scores.rds               # Basic scores (11 indicators)
├── fii_scores_enriched.rds      # + Deep indicators (20+ total)
├── fii_scores_enriched.csv      # CSV export
├── fii_cvm.rds                  # CVM official data
├── fii_analyses_YYYYMMDD.rds   # Individual analyses
├── pipeline_metadata.rds        # Execution metadata
└── .logs/
    └── pipeline_*.log           # Execution logs

data_backup/
└── fii_scores_*_YYYYMMDD_HHMMSS.rds  # Auto backups

reports/
└── YYYY-MM-DD/
    ├── KNRI11_analysis.md       # Individual reports
    ├── MXRF11_analysis.md
    └── opportunities_summary.md  # Opportunities
```

## Deep Indicators (Phase 4)

**Quality Block (4):**
- `alavancagem` - Leverage ratio (passivo/PL)
- `concentracao_cotistas` - Shareholder concentration
- `estabilidade_patrimonio` - Equity stability (CV)
- `taxa_eficiencia` - Management fee efficiency

**Temporal Block (6):**
- `momentum_3m`, `momentum_6m`, `momentum_12m` - Rate of change
- `trend_dy` - DY trend slope (regression)
- `vol_dy`, `vol_rentabilidade` - Volatility metrics

**Relative Block (5):**
- `zscore_dy`, `zscore_pvp` - Z-scores vs segment
- `percentile_dy`, `percentile_pvp` - Percentile ranks
- `relative_strength_12m` - Performance vs peers

## Quick Checks After Execution

```r
# Check success
result$summary$overall_success  # TRUE/FALSE

# Load scores
scores <- readRDS("data/fii_scores_enriched.rds")

# Top 10
scores %>% arrange(desc(total_score)) %>% head(10)

# Buy recommendations
scores %>% filter(recommendation == "COMPRAR")

# Deep indicators sample
scores %>% select(ticker, alavancagem, momentum_12m, zscore_dy)

# View analyses
analyses <- readRDS("data/fii_analyses_20260321.rds")
analyses$KNRI11

# Check logs
readLines("data/.logs/pipeline_20260321_153045.log") %>% tail(50)
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Phase 1 fails | Check internet, Google Sheets credentials |
| CVM validation warnings | Normal for missing CNPJ, add to mapping if needed |
| Deep indicators = NA | Need fii_cvm.rds and fii_scores_history.rds |
| Analysis slow | Limit tickers: `tickers="portfolio"` |
| Out of memory | Reduce tickers or use mode="incremental" |

## Integration Examples

### Load and Explore Enriched Scores
```r
scores <- readRDS("data/fii_scores_enriched.rds")

# Filter high-quality low-leverage FIIs
scores %>%
  filter(quality_score > 75, alavancagem < 0.3) %>%
  arrange(desc(total_score))

# Find momentum leaders
scores %>%
  filter(!is.na(momentum_12m)) %>%
  arrange(desc(momentum_12m)) %>%
  select(ticker, momentum_12m, total_score, dy_12m)

# Z-score analysis
scores %>%
  filter(!is.na(zscore_dy)) %>%
  filter(zscore_dy > 1) %>%  # Above average DY
  arrange(desc(zscore_dy))
```

### Custom Opportunity Finder
```r
# High yield, low P/VP, positive momentum
opportunities <- scores %>%
  filter(
    dy_12m > 8,           # >8% yield
    pvp < 1.0,            # Below par
    momentum_12m > 0,     # Improving
    alavancagem < 0.5,    # Low leverage
    total_score > 70      # Quality threshold
  ) %>%
  arrange(desc(total_score))
```

### Track Score Changes
```r
history <- readRDS("data/fii_scores_history.rds")

# FIIs with biggest score improvements
history %>%
  arrange(ticker, calculated_at) %>%
  group_by(ticker) %>%
  filter(n() >= 2) %>%
  summarise(
    latest = last(total_score),
    oldest = first(total_score),
    change = latest - oldest
  ) %>%
  arrange(desc(change))
```

## Scheduled Execution

### Daily (cron/Task Scheduler)
```r
# daily_update.R
source("R/pipeline/main_complete_pipeline.R")
result <- run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",
  include_cvm = FALSE,
  include_deep_indicators = TRUE,
  include_analysis = FALSE,
  log_level = "INFO"
)
if (!result$summary$overall_success) {
  stop("Pipeline failed!")
}
```

### Weekly (Sunday nights)
```r
# weekly_refresh.R
source("R/pipeline/main_complete_pipeline.R")
result <- run_complete_analysis(
  mode = "full",
  tickers = "all",
  include_cvm = FALSE,
  include_deep_indicators = TRUE,
  include_analysis = FALSE
)
```

### Monthly (1st day of month)
```r
# monthly_deep.R
source("R/pipeline/main_complete_pipeline.R")
result <- run_complete_analysis(
  mode = "full",
  tickers = "all",
  include_cvm = TRUE,
  include_deep_indicators = TRUE,
  include_analysis = TRUE,
  include_reports = TRUE
)
```

## Performance Tips

1. **Use incremental mode** for daily updates
2. **Limit tickers** for faster analysis
3. **Skip CVM** except monthly (cache is 30 days)
4. **Disable analysis/reports** for quick runs
5. **Use portfolio mode** for personal tracking

## Dependencies Check

```r
# Required packages
packages <- c("tidyverse", "lubridate", "glue", "yaml",
              "httr2", "rvest", "googlesheets4")
missing <- packages[!packages %in% installed.packages()[,"Package"]]
if (length(missing) > 0) {
  install.packages(missing)
}

# Required files
required_files <- c(
  "R/pipeline/hybrid_pipeline.R",
  "R/transform/fii_score_pipeline.R",
  "R/transform/fii_deep_indicators.R",
  "R/import/fii_cvm_data.R",
  "R/validators/cvm_validator.R",
  "config/pipeline_config.yaml"
)
all(file.exists(required_files))
```

## Next Steps After Pipeline

1. **Explore scores**: Open RStudio, load data/fii_scores_enriched.rds
2. **Find opportunities**: Run R/analysis/fii_opportunities.R
3. **Generate dashboard**: Render R/dashboard/portfolio.Rmd
4. **Review reports**: Open reports/YYYY-MM-DD/ in text editor
5. **Analyze specific FII**: Use R/analysis/fii_individual_analysis.R

## Support

- **Logs**: `data/.logs/pipeline_*.log`
- **Validation**: Check `result$phase_results$clean`
- **Errors**: Inspect `result$errors`
- **Documentation**: `docs/pipeline_v3_usage.md`

---

**Version:** 3.0.0 | **Date:** 2026-03-21
