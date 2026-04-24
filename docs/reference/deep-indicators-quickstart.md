# Deep Indicators Quick Start Guide

## 5-Minute Getting Started

### Step 1: Load the Module
```r
source("R/transform/fii_deep_indicators.R")
```

### Step 2: Load Cache
```r
cache <- load_deep_indicators_cache()
```

### Step 3: Calculate for One FII
```r
indicators <- calculate_all_deep_indicators("KNRI11", cache)
print(indicators)
```

### Step 4: Enrich All Scores
```r
basic_scores <- readRDS("data/fii_scores.rds")
enriched <- enrich_scores_with_deep_indicators(basic_scores, cache)
saveRDS(enriched, "data/fii_scores_enriched.rds")
```

---

## Most Useful Indicators

### Quality (Lower is Better)
- **alavancagem** < 0.3 = Low leverage ✓
- **concentracao_cotistas** < 0.4 = Diversified ✓
- **estabilidade_patrimonio** < 0.05 = Very stable ✓
- **taxa_eficiencia** < 1.0% = Efficient ✓

### Momentum (Higher is Better)
- **momentum_3m** > 5% = Strong recent performance ✓
- **momentum_6m** > 10% = Strong mid-term ✓
- **momentum_12m** > 15% = Strong long-term ✓

### Relative (Interpretation Varies)
- **zscore_dy** > 1 = Top quartile DY ✓
- **percentile_dy** > 75 = Top 25% ✓
- **relative_strength_12m** > 0 = Outperforming peers ✓

---

## Common Queries

### Find High-Quality FIIs
```r
enriched %>%
  filter(
    alavancagem < 0.3,
    concentracao_cotistas < 0.4,
    estabilidade_patrimonio < 0.05
  ) %>%
  arrange(desc(total_score))
```

### Find Momentum Winners
```r
enriched %>%
  filter(
    momentum_3m > 0,
    momentum_6m > 0,
    trend_dy > 0
  ) %>%
  arrange(desc(momentum_3m))
```

### Find Segment Leaders
```r
enriched %>%
  filter(
    percentile_dy > 75,
    zscore_dy > 0.5,
    relative_strength_12m > 0
  ) %>%
  arrange(desc(percentile_dy))
```

### Find Undervalued Quality
```r
enriched %>%
  filter(
    alavancagem < 0.3,           # Good quality
    estabilidade_patrimonio < 0.05,
    pvp < 0.95,                   # Trading at discount
    zscore_dy > 0                 # Above-average yield
  ) %>%
  arrange(pvp)
```

---

## Interpreting Results

### Alavancagem (Leverage)
- 0.0 - 0.2: Conservative ✓
- 0.2 - 0.4: Moderate
- 0.4 - 0.7: Elevated ⚠️
- > 0.7: High risk ⛔

### Concentração Cotistas (Concentration)
- < 0.3: Very diversified ✓
- 0.3 - 0.4: Diversified ✓
- 0.4 - 0.5: Moderate concentration ⚠️
- > 0.5: Concentrated ⛔

### Z-Score (Segment Comparison)
- > 1.5: Excellent (top 7%)
- 0.5 - 1.5: Good (above average)
- -0.5 - 0.5: Average
- < -1.5: Poor (bottom 7%)

### Percentile Rank
- 90-100: Top decile ✓
- 75-90: Top quartile ✓
- 25-75: Middle range
- < 25: Bottom quartile ⛔

---

## Troubleshooting

**Q: All indicators are NA**
A: Missing CVM data. Run `source("R/import/fii_cvm_data.R")` first.

**Q: Relative indicators are NA**
A: Need at least 3 FIIs in same segment. Check segment classification.

**Q: Momentum/trend are NA**
A: Need scores_history. Set `history_file` parameter or accept NAs.

**Q: Function not found**
A: Run `source("R/transform/fii_deep_indicators.R")` to load functions.

---

## Data Requirements

| Feature | Required Files |
|---------|----------------|
| Quality indicators | fii_cvm.rds |
| Volatility | fii_cvm.rds |
| Momentum/Trend | scores_history.rds (optional) |
| Relative indicators | fii_scores.rds + fiis.rds |
| Full analysis | All of the above |

---

## One-Liner Recipes

### Load everything
```r
source("R/transform/fii_deep_indicators.R"); cache <- load_deep_indicators_cache()
```

### Quick single FII
```r
calculate_all_deep_indicators("KNRI11", cache)
```

### Batch enrich and save
```r
enrich_scores_with_deep_indicators(readRDS("data/fii_scores.rds"), cache) %>% saveRDS("data/fii_scores_enriched.rds")
```

### Top quality FIIs
```r
enriched %>% arrange(alavancagem, concentracao_cotistas) %>% head(10)
```

### Segment summary
```r
enriched %>% group_by(tipo_fii) %>% summarise(across(c(alavancagem, momentum_3m), mean, na.rm=T))
```

---

## Full Documentation

For complete reference, see:
- Implementation guide: `docs/deep_indicators_implementation.md`
- Usage examples: `R/_draft/example_deep_indicators_usage.R`
- Test suite: `R/_draft/test_deep_indicators.R`
- Source code: `R/transform/fii_deep_indicators.R`
