# FII Analysis Layer

**Purpose:** High-level analysis using PRE-CALCULATED scores

**Architecture:** Import → Transform (scoring) → **Analysis (fast queries)**

---

## 📋 Overview

This layer provides fast analytical queries by reading pre-calculated scores from the transform layer.

### Architecture Principle

```
┌─────────────────────────────────────────────────────────┐
│  IMPORT (R/import/)                                     │
│  Collect raw data from sources                          │
│  Output: data/*.rds (portfolio, quotes, income, fiis)   │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│  TRANSFORM (R/transform/)                               │
│  Calculate scores (run once in pipeline)                │
│  Output: data/fii_scores.rds ← PRE-CALCULATED           │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│  ANALYSIS (R/analysis/) ← THIS LAYER                    │
│  Fast queries on pre-calculated scores                  │
│  Operations: rank, filter, compare, visualize          │
└─────────────────────────────────────────────────────────┘
```

**Key Benefit:** Analysis is instant (0.1-1s) because scores are pre-calculated.

---

## 🚀 Quick Start

### 1. Run Pipeline (First Time or Daily)

```r
# Complete pipeline: import + scoring
source("R/pipeline/main_portfolio_with_scoring.R")
```

**Output:** Creates `data/fii_scores.rds` with all calculated scores

---

### 2. Run Analysis (Instant)

```r
# Load analysis functions
source("R/analysis/analysis_examples.R")

# Quick test
quick_test_analysis()

# Or run specific analyses
example1_portfolio_analysis()
example2_find_opportunities()
```

**Speed:** Instant queries (< 1s) using pre-calculated scores

---

## 📊 Available Analyses

### 1. Portfolio Analysis

```r
source("R/analysis/fii_analysis.R")

# Get portfolio with scores and positions
portfolio_scores <- get_portfolio_scores()

# Print summary
print_portfolio_summary()

# Top performers
print_ranking(portfolio_scores, top_n = 10)
```

**Output:**
```
═══════════════════════════════════════════════════════════════
                   PORTFOLIO SUMMARY
═══════════════════════════════════════════════════════════════

💰 Financial:
   Total Invested:      R$ 150.000,00
   Current Value:       R$ 165.000,00
   Unrealized Gain:     R$ 15.000,00
   Return:              10,0%

📊 Scores:
   Mean Score:          45.2
   Median Score:        42.8
   Weighted DY:         8,5%

📈 Recommendations:
   🟢 COMPRAR:   5 (8%)
   🟡 MANTER:    15 (25%)
   🟠 OBSERVAR:  20 (33%)
   🔴 EVITAR:    20 (33%)
```

---

### 2. Find Opportunities

```r
# Find high-quality FIIs with good valuations
opportunities <- find_opportunities(
  min_score = 70,     # Minimum score
  min_dy = 8,         # Minimum dividend yield
  max_pvp = 1.0,      # Maximum P/VP
  tipo_fii = "Log"    # Optional: filter by type
)

print_ranking(opportunities)
```

---

### 3. Peer Comparison

```r
source("R/analysis/fii_comparison.R")

# Compare with same-segment peers
comparison <- compare_with_peers("HGLG11", max_peers = 5)
print_comparison_report(comparison)
```

**Output:**
```
═══════════════════════════════════════════════════════════════
           COMPARATIVE ANALYSIS: HGLG11
═══════════════════════════════════════════════════════════════

📊 Score Comparison:
  HGLG11: 33.5/100
  Peer Average: 52.3/100
  Difference: -18.8 points

✅ Better than peers in: Quality
⚠️  Worse than peers in: Income, Valuation, Risk
```

---

### 4. Segment Analysis

```r
# Analyze all FIIs in segment
summary <- analyze_segment("Lajes Corporativas")

# Get full segment scores
scores <- load_scores_for_analysis()
segment_scores <- scores %>%
  filter(str_detect(tipo_fii, "Lajes"))
```

---

### 5. Single FII Report

```r
# Detailed report for one FII
print_fii_report("HGLG11")
```

---

### 6. Historical Changes

```r
# See which FIIs had significant score changes
print_score_changes(min_change = 5)

# Get history for specific FII
source("R/transform/fii_score_pipeline.R")
history <- get_score_history("HGLG11")
```

---

### 7. Portfolio vs Market

```r
# Compare portfolio performance with market
comparison <- portfolio_vs_market()
print_portfolio_vs_market(comparison)
```

---

## 📈 Functions Reference

### `fii_analysis.R` (Main Analysis Functions)

| Function | Purpose | Speed |
|----------|---------|-------|
| `get_portfolio_scores()` | Portfolio + scores + positions | 0.1s |
| `rank_fiis(filter, top_n)` | Ranked FIIs by score | 0.1s |
| `find_opportunities(...)` | Filter by criteria | 0.2s |
| `get_fii_score(ticker)` | Single FII score | 0.1s |
| `print_fii_report(ticker)` | Formatted report | 0.1s |
| `portfolio_summary()` | Portfolio statistics | 0.2s |
| `print_portfolio_summary()` | Formatted summary | 0.2s |

### `fii_comparison.R` (Peer Analysis)

| Function | Purpose | Speed |
|----------|---------|-------|
| `compare_with_peers(ticker)` | Peer comparison | 0.2s |
| `print_comparison_report(comp)` | Format comparison | 0.1s |
| `analyze_segment(tipo_fii)` | Segment statistics | 0.2s |
| `portfolio_vs_market()` | Portfolio vs market | 0.3s |
| `print_portfolio_vs_market(comp)` | Format report | 0.1s |

**All analysis functions are fast (< 1s) because they read pre-calculated scores!**

---

## 🎯 Common Workflows

### Daily Portfolio Review

```r
# 1. Run pipeline (morning)
source("R/pipeline/main_portfolio_with_scoring.R")

# 2. Review portfolio (instant)
source("R/analysis/fii_analysis.R")
print_portfolio_summary()

# 3. Check changes
print_score_changes(min_change = 3)

# 4. Find new opportunities
opportunities <- find_opportunities(min_score = 70, min_dy = 8)
```

---

### Research Workflow

```r
# 1. Load scores
source("R/analysis/fii_analysis.R")
scores <- load_scores_for_analysis()

# 2. Filter and explore
logistics_fiis <- scores %>%
  filter(str_detect(tipo_fii, "Log"),
         total_score > 60)

# 3. Compare top picks
compare_with_peers("HGLG11")

# 4. Segment overview
analyze_segment("Logística")
```

---

### Decision Support

```r
# Should I buy HGLG11?
print_fii_report("HGLG11")              # See score & recommendation
compare_with_peers("HGLG11")            # vs peers
get_score_history("HGLG11")             # Historical trend

# Should I rebalance?
print_portfolio_summary()               # Current allocation
portfolio_vs_market()                   # vs market performance
get_score_changes(min_change = 5)       # Recent changes
```

---

## 🔧 Advanced Usage

### Custom Ranking

```r
scores <- load_scores_for_analysis()

# Best high-yield FIIs
best_yield <- scores %>%
  filter(dy_12m > 10, quality > 60) %>%
  arrange(desc(total_score))

# Best value (discount + quality)
best_value <- scores %>%
  filter(pvp < 0.9, quality > 70) %>%
  arrange(pvp)

# Conservative (low risk, stable income)
conservative <- scores %>%
  filter(risk > 70, income > 60) %>%
  arrange(desc(total_score))
```

---

### Portfolio Optimization Prep

```r
# Get underperformers to consider selling
portfolio_scores <- get_portfolio_scores()

to_review <- portfolio_scores %>%
  filter(
    recommendation == "EVITAR" |
    total_score < 40 |
    unrealized_return_pct < -20
  ) %>%
  arrange(total_score)

# Get better alternatives in same segment
alternatives <- map_dfr(to_review$ticker, function(ticker) {
  peers <- compare_with_peers(ticker, max_peers = 3)

  peers$peer_scores %>%
    filter(total_score > to_review$total_score[to_review$ticker == ticker]) %>%
    head(1)
})
```

---

### Export to Excel

```r
# Portfolio scores with formatting
portfolio_scores <- get_portfolio_scores()

portfolio_scores %>%
  select(ticker, tipo_fii, total_score, quality, income,
         valuation, risk, recommendation, dy_12m, pvp,
         current_price, shares, invested, current_value,
         unrealized_return_pct) %>%
  write_csv("exports/portfolio_analysis.csv")
```

---

## ⚠️ Important Notes

### Always Run Pipeline First

```r
# Before first analysis, run pipeline
source("R/pipeline/main_portfolio_with_scoring.R")

# This creates data/fii_scores.rds
```

### Check Score Age

```r
scores <- readRDS("data/fii_scores.rds")
age <- difftime(Sys.time(), max(scores$calculated_at), units = "hours")

if (age > 24) {
  message("Scores are ", round(age, 0), "h old. Consider refreshing.")
}
```

### Data Quality

Always check `data_completeness`:
```r
scores %>%
  filter(data_completeness < 0.75) %>%
  select(ticker, data_completeness, recommendation)
```

---

## 📚 See Also

- **Transform Layer:** `R/transform/README.md` - Score calculation details
- **Pipeline:** `R/pipeline/main_portfolio_with_scoring.R` - Complete pipeline
- **Examples:** `R/analysis/analysis_examples.R` - Usage examples

---

**Last Updated:** 2026-03-20
**Version:** 1.0.0 (Refactored)
**Status:** ✅ Production Ready
