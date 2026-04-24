# Deep Indicators Implementation Guide

## Overview

The `fii_deep_indicators.R` module implements advanced multi-factor indicators for FII analysis, complementing the basic indicators in `fii_indicators.R`. These indicators provide deeper insights into fund quality, momentum, trends, and relative performance.

**File:** `/R/transform/fii_deep_indicators.R`
**Lines of code:** 771
**Functions implemented:** 16
**Test coverage:** `/R/_draft/test_deep_indicators.R`

---

## Architecture

The module follows the established pattern from `fii_indicators.R` with individual `calc_*()` functions and consolidation functions.

### Data Flow

```
CVM Data + Scores History + FII Info
            ↓
    calculate_all_deep_indicators()
            ↓
    Individual calc_*() functions
            ↓
    Tibble with all indicators
            ↓
    enrich_scores_with_deep_indicators()
            ↓
    Enriched scores ready for analysis
```

---

## Indicator Categories

### 1. QUALITY INDICATORS (Block A Enhancement)

These indicators assess fundamental fund quality based on CVM data.

#### `calc_alavancagem(cvm_data)`
- **Purpose:** Measures fund leverage (debt/equity ratio)
- **Data source:** CVM passivo/patrimônio_liquido
- **Fallback:** Uses patrimônio volatility (CV) as leverage proxy when passivo unavailable
- **Interpretation:** Lower is better (< 0.3 is good, > 0.7 is high risk)

#### `calc_concentracao_cotistas(cvm_data)`
- **Purpose:** Shareholder concentration risk
- **Formula:** `1 / log10(numero_cotistas + 10)`
- **Interpretation:** Lower is better (< 0.4 = diversified, > 0.6 = concentrated)

#### `calc_estabilidade_patrimonio(cvm_data)`
- **Purpose:** Equity base stability over 12 months
- **Formula:** Coefficient of variation of patrimônio_liquido
- **Interpretation:** Lower is better (< 0.05 = very stable, > 0.15 = volatile)

#### `calc_taxa_eficiencia(cvm_data)`
- **Purpose:** Management efficiency ratio
- **Formula:** Taxa de administração / patrimônio líquido
- **Interpretation:** Lower is better (< 0.5% = efficient, > 1.5% = expensive)

---

### 2. TEMPORAL INDICATORS (Trend Analysis)

These indicators analyze trends and momentum over time.

#### `calc_momentum(indicator_history, windows = c(3, 6, 12))`
- **Purpose:** Rate of change over multiple time windows
- **Returns:** Named list with `momentum_3m`, `momentum_6m`, `momentum_12m`
- **Input:** Tibble with `date` and `indicator_value` columns
- **Interpretation:** Positive = improving, negative = declining

#### `calc_trend_score(indicator_history, min_points = 6)`
- **Purpose:** Linear regression slope (trend direction and strength)
- **Method:** Fits `lm(indicator_value ~ time_index)` and returns annualized slope
- **Interpretation:** Positive = upward trend, negative = downward trend

#### `calc_volatility_indicators(indicator_history, indicators)`
- **Purpose:** Coefficient of variation for key metrics (DY, rentabilidade)
- **Returns:** Named list with `vol_dy`, `vol_rentabilidade`
- **Interpretation:** Lower = more stable/predictable

---

### 3. RELATIVE INDICATORS (Segment Comparison)

These indicators compare a FII against its segment peers.

#### `calc_zscore_segment(value, segment_data)`
- **Purpose:** Standard deviations from segment mean
- **Interpretation:** z > 1 = top quartile, z < -1 = bottom quartile

#### `calc_percentile_rank(value, segment_data)`
- **Purpose:** Percentile ranking within segment (0-100)
- **Interpretation:** 75+ = top quartile, 25- = bottom quartile

#### `calc_relative_strength(ticker, all_data, window = 12)`
- **Purpose:** Performance vs segment average over window
- **Returns:** Percentage outperformance/underperformance
- **Interpretation:** Positive = outperforming peers, negative = underperforming

---

### 4. HELPER FUNCTIONS

#### `get_segment_peers(ticker, all_data)`
Returns list of tickers in same segment (tipo_fii or segmento).

#### `calculate_segment_statistics(segment_data, indicator)`
Returns comprehensive stats: mean, sd, median, q25, q75, n.

#### `normalize_to_scale(value, min_val, max_val, scale = 100)`
Normalizes value from `[min_val, max_val]` to `[0, scale]`.

---

### 5. CONSOLIDATION FUNCTIONS

#### `calculate_all_deep_indicators(ticker, cache)`

**Main calculation function** that computes all deep indicators for a single ticker.

**Required cache structure:**
```r
cache <- list(
  cvm_data = tibble(...),        # From fii_cvm.rds
  fiis = tibble(...),             # From fiis.rds (for segment info)
  scores = tibble(...),           # From fii_scores.rds (for relative indicators)
  scores_history = tibble(...)    # Optional: for momentum/trend
)
```

**Returns:** Tibble with one row and 15+ indicator columns.

**Example:**
```r
cache <- load_deep_indicators_cache()
indicators <- calculate_all_deep_indicators("KNRI11", cache)
```

#### `enrich_scores_with_deep_indicators(basic_scores, cache)`

**Batch enrichment function** that adds deep indicators to existing scores.

**Input:** Basic scores from `fii_scores.rds`
**Output:** Enriched scores with additional columns
**Progress:** Shows progress bar for batch processing

**Example:**
```r
basic_scores <- readRDS("data/fii_scores.rds")
cache <- load_deep_indicators_cache()
enriched <- enrich_scores_with_deep_indicators(basic_scores, cache)
saveRDS(enriched, "data/fii_scores_enriched.rds")
```

#### `load_deep_indicators_cache()`

**Convenience function** to load all necessary data files.

**Parameters:**
- `cvm_file`: Path to fii_cvm.rds (default: `data/fii_cvm.rds`)
- `scores_file`: Path to fii_scores.rds (default: `data/fii_scores.rds`)
- `fiis_file`: Path to fiis.rds (default: `data/fiis.rds`)
- `history_file`: Optional path to scores history

**Example:**
```r
cache <- load_deep_indicators_cache(
  cvm_file = "data/fii_cvm.rds",
  scores_file = "data/fii_scores.rds",
  fiis_file = "data/fiis.rds",
  history_file = "data/scores_history.rds"  # Optional
)
```

---

## Output Schema

The enriched scores tibble contains these additional columns:

### Quality Block (4 columns)
- `alavancagem`: Leverage ratio (0-1+)
- `concentracao_cotistas`: Concentration risk (0-1)
- `estabilidade_patrimonio`: Equity stability CV
- `taxa_eficiencia`: Management fee efficiency (%)

### Temporal Block (6 columns)
- `momentum_3m`: 3-month momentum (%)
- `momentum_6m`: 6-month momentum (%)
- `momentum_12m`: 12-month momentum (%)
- `trend_dy`: DY trend score (annualized slope)
- `vol_dy`: DY volatility (CV)
- `vol_rentabilidade`: Rentabilidade volatility (CV)

### Relative Block (5 columns)
- `zscore_dy`: DY z-score vs segment
- `zscore_pvp`: P/VP z-score vs segment
- `percentile_dy`: DY percentile rank (0-100)
- `percentile_pvp`: P/VP percentile rank (0-100)
- `relative_strength_12m`: 12M performance vs peers (%)

**Total:** 15 additional columns

---

## Usage Patterns

### Pattern 1: Single FII Analysis
```r
source("R/transform/fii_deep_indicators.R")

cache <- load_deep_indicators_cache()
indicators <- calculate_all_deep_indicators("KNRI11", cache)

# View quality indicators
indicators %>%
  select(ticker, alavancagem, concentracao_cotistas, estabilidade_patrimonio)
```

### Pattern 2: Batch Enrichment
```r
basic_scores <- readRDS("data/fii_scores.rds")
cache <- load_deep_indicators_cache()

enriched <- enrich_scores_with_deep_indicators(basic_scores, cache)
saveRDS(enriched, "data/fii_scores_enriched.rds")
```

### Pattern 3: Segment Analysis
```r
enriched <- readRDS("data/fii_scores_enriched.rds")
fiis <- readRDS("data/fiis.rds")

segment_analysis <- enriched %>%
  left_join(fiis %>% select(ticker, tipo_fii), by = "ticker") %>%
  group_by(tipo_fii) %>%
  summarise(
    avg_alavancagem = mean(alavancagem, na.rm = TRUE),
    avg_momentum_3m = mean(momentum_3m, na.rm = TRUE),
    avg_zscore_dy = mean(zscore_dy, na.rm = TRUE)
  )
```

### Pattern 4: Opportunity Screening
```r
opportunities <- enriched %>%
  filter(
    alavancagem < 0.3,              # Low leverage
    concentracao_cotistas < 0.4,    # Diversified shareholders
    momentum_3m > 0,                 # Positive momentum
    zscore_dy > 0.5                  # Above-average DY
  ) %>%
  arrange(desc(total_score))
```

---

## Data Dependencies

### Required Data Files
1. **fii_cvm.rds** - CVM monthly reports (essential for quality indicators)
   - Columns: ticker, data_competencia, patrimonio_liquido, numero_cotistas, etc.
   - Source: `R/import/fii_cvm_data.R`

2. **fii_scores.rds** - Basic scores (essential for relative indicators)
   - Columns: ticker, total_score, dy_12m, pvp, etc.
   - Source: `R/transform/fii_scoring.R`

3. **fiis.rds** - FII metadata (essential for segment analysis)
   - Columns: ticker, tipo_fii, segmento, etc.
   - Source: `R/import/` (various sources)

### Optional Data Files
4. **scores_history.rds** - Historical scores (for momentum/trend)
   - Columns: ticker, calculated_at, dy_12m, total_score, etc.
   - Source: Manual collection or pipeline with history tracking

### Data Availability Matrix

| Indicator | CVM Required | Scores Required | FII Info Required | History Required |
|-----------|--------------|-----------------|-------------------|------------------|
| Alavancagem | ✓ | | | |
| Concentração | ✓ | | | |
| Estabilidade | ✓ | | | |
| Taxa Eficiência | ✓ | | | |
| Momentum | | | | ✓ |
| Trend | | | | ✓ |
| Volatility | ✓ | | | |
| Z-scores | | ✓ | ✓ | |
| Percentiles | | ✓ | ✓ | |
| Relative Strength | | | ✓ | ✓ |

---

## Handling Missing Data

All `calc_*()` functions return `NA_real_` when data is insufficient:
- Too few data points (< 3 for most calculations)
- Missing required fields
- Invalid values (zeros, negatives where inappropriate)

The consolidation functions handle NAs gracefully:
- Individual indicators can be NA without breaking the pipeline
- Relative indicators require segment peers (skip if < 3 peers)
- Temporal indicators require history (skip if unavailable)

**Strategy:** Start with available data, add more as data sources improve.

---

## Integration with Scoring System

Deep indicators can be integrated into the existing scoring framework in two ways:

### Option A: Separate Deep Score Block
Add a 5th scoring block (10% weight) with deep indicators.

### Option B: Enhance Existing Blocks
Use deep indicators to refine existing block calculations:
- Quality Block: Add alavancagem, concentracao, estabilidade
- Income Block: Add momentum, trend for stability score
- Valuation Block: Add zscore_pvp for relative valuation
- Risk Block: Add volatility indicators

**Recommendation:** Start with Option B (enhance existing blocks) for seamless integration.

---

## Testing

### Unit Tests
Run: `Rscript R/_draft/test_deep_indicators.R`

Tests cover:
- All quality indicators with mock CVM data
- Temporal indicators with synthetic time series
- Relative indicators with mock segment data
- Helper functions
- Consolidation pipeline

### Integration Tests
Example: `Rscript R/_draft/example_deep_indicators_usage.R`

Demonstrates:
- Single FII calculation
- Batch enrichment
- Segment analysis
- Opportunity screening
- Side-by-side comparison

---

## Performance Considerations

- **Single ticker:** ~50ms (depends on CVM data size)
- **Batch (100 FIIs):** ~5-10 seconds with progress bar
- **Relative indicators:** Require segment peer lookups (add ~10ms per ticker)
- **Temporal indicators:** Require historical data joins (add ~20ms per ticker)

**Optimization tips:**
- Load cache once, reuse for all calculations
- Use `enrich_scores_with_deep_indicators()` for batch processing
- Cache segment peer lists if calculating repeatedly

---

## Future Enhancements

1. **Historical Tracking**
   - Implement `data/scores_history.rds` with monthly snapshots
   - Enable full momentum/trend analysis
   - Track indicator evolution over time

2. **Advanced Quality Metrics**
   - Add passivo data to CVM collection for true leverage calculation
   - Include concentração de ativos (asset concentration)
   - Add gestora quality score (based on track record)

3. **Market Regime Indicators**
   - Detect market regime shifts (bull/bear/sideways)
   - Adjust relative indicators for regime
   - Add correlation with IFIX/CDI

4. **Machine Learning Features**
   - Use deep indicators as ML features
   - Train models for return prediction
   - Optimize indicator weights automatically

---

## Troubleshooting

### Issue: All indicators return NA
**Cause:** Missing or empty CVM data
**Solution:** Run `source("R/import/fii_cvm_data.R")` to collect CVM data

### Issue: Relative indicators are NA
**Cause:** Insufficient segment peers (< 3)
**Solution:** Check segment classification in fiis.rds, ensure enough FIIs per segment

### Issue: Temporal indicators are NA
**Cause:** No scores_history available
**Solution:** Either provide history_file parameter or accept NAs for momentum/trend

### Issue: Slow batch processing
**Cause:** Large number of FIIs with full history
**Solution:** Filter to portfolio FIIs only, or run in parallel (future enhancement)

---

## References

- **Basic Indicators:** `R/transform/fii_indicators.R`
- **Scoring Framework:** `R/transform/fii_scoring.R`
- **CVM Data Collection:** `R/import/fii_cvm_data.R`
- **Data Sources Layer:** `R/transform/fii_data_sources.R`

---

## Contact & Support

**Author:** Claude Code
**Date:** 2026-03-21
**Version:** 1.0.0

For questions or issues, refer to:
- Test suite: `R/_draft/test_deep_indicators.R`
- Usage examples: `R/_draft/example_deep_indicators_usage.R`
- This guide: `docs/deep_indicators_implementation.md`
