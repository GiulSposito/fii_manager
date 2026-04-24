# FII Manager - Quick Start (New Architecture)

**Version:** 2.0.0
**Last Updated:** 2026-03-20
**Architecture:** Import → Transform → Analysis ✅

---

## 🚀 Get Started in 2 Steps

### Step 1: Run Pipeline (First Time or Daily)

```r
# Run complete pipeline: Import data + Calculate scores
source("R/pipeline/main_portfolio_with_scoring.R")
```

**What it does:**
1. Imports portfolio, prices, income, market data
2. Calculates scores for all FIIs
3. Saves to `data/fii_scores.rds`

**Time:** ~2 minutes (one-time calculation)

---

### Step 2: Run Analysis (Instant Anytime)

```r
# Load analysis tools
source("R/analysis/analysis_examples.R")

# Quick test
quick_test_analysis()

# Or run specific analysis
example1_portfolio_analysis()      # Portfolio overview
example2_find_opportunities()      # Find FIIs to buy
```

**Time:** < 1 second (reads pre-calculated scores)

---

## 📊 What You Get

### Portfolio Analysis (Instant)

```r
source("R/analysis/fii_analysis.R")
print_portfolio_summary()
```

**Output:**
```
💰 Financial:
   Total Invested:      R$ 150.000,00
   Current Value:       R$ 165.000,00
   Return:              10,0%

📊 Scores:
   Mean Score:          45.2
   Median Score:        42.8
   Weighted DY:         8,5%

📈 Recommendations:
   🟢 COMPRAR:   5 (8%)
   🔴 EVITAR:    20 (33%)
```

---

### Find Opportunities (Instant)

```r
opportunities <- find_opportunities(
  min_score = 70,
  min_dy = 8,
  max_pvp = 1.0
)

print_ranking(opportunities)
```

---

### Compare with Peers (Instant)

```r
source("R/analysis/fii_comparison.R")
compare_with_peers("HGLG11", max_peers = 5)
```

---

## 🏗️ Architecture

```
┌────────────────────┐
│  IMPORT            │  Collect raw data
│  R/import/         │  (portfolio, prices, income)
└────────┬───────────┘
         │
┌────────▼───────────┐
│  TRANSFORM         │  Calculate scores ONCE
│  R/transform/      │  Output: data/fii_scores.rds
└────────┬───────────┘
         │
┌────────▼───────────┐
│  ANALYSIS          │  Fast queries (instant)
│  R/analysis/       │  Read pre-calculated scores
└────────────────────┘
```

**Key Benefit:** Scores calculated once, used many times = 400-600x faster queries

---

## ⚡ Performance

| Operation | Old | New | Improvement |
|-----------|-----|-----|-------------|
| Portfolio summary | 2 min | 0.2 s | **600x** |
| Find opportunities | 2 min | 0.3 s | **400x** |
| Single FII report | 2 s | 0.1 s | **20x** |

---

## 📚 Documentation

- **Transform Layer:** `R/transform/README.md`
- **Analysis Layer:** `R/analysis/README.md`
- **Refactoring Details:** `docs/REFACTORING_SUMMARY_2026-03-20.md`

---

## 🎯 Common Workflows

### Daily Morning Routine

```r
# 1. Update data + scores (2 min)
source("R/pipeline/main_portfolio_with_scoring.R")

# 2. Review portfolio (instant)
source("R/analysis/fii_analysis.R")
print_portfolio_summary()

# 3. Check changes (instant)
source("R/transform/fii_score_pipeline.R")
print_score_changes(min_change = 3)
```

---

### Research Workflow

```r
# Load scores (instant)
source("R/analysis/fii_analysis.R")
scores <- load_scores_for_analysis()

# Filter by criteria
logistics <- scores %>%
  filter(str_detect(tipo_fii, "Log"),
         total_score > 60)

# Compare with peers
source("R/analysis/fii_comparison.R")
compare_with_peers("HGLG11")
```

---

## 💡 Tips

1. **Run pipeline daily** (morning recommended)
   - Keeps scores fresh
   - Analysis always instant

2. **Use pre-calculated scores**
   - Don't recalculate unless data changed
   - Read from `data/fii_scores.rds`

3. **Track changes**
   - History file tracks last 30 days
   - Detect score improvements/degradation

---

## ✅ Prerequisites

**First time only:**

```r
# Install packages (if needed)
install.packages(c("tidyverse", "lubridate", "glue"))

# Run pipeline to create scores
source("R/pipeline/main_portfolio_with_scoring.R")
```

**That's it!** Now all analysis is instant.

---

## 🆘 Troubleshooting

### "No scores found"

```r
# Run pipeline first
source("R/pipeline/main_portfolio_with_scoring.R")
```

### "Scores are stale"

```r
# Refresh scores
source("R/transform/fii_score_pipeline.R")
run_scoring_pipeline(force = TRUE)
```

### "Analysis is slow"

Make sure you're using new architecture:

```r
# ❌ OLD (slow - calculates on-demand)
source("R/analysis/fii_score.R")
calculate_fii_score("HGLG11")

# ✅ NEW (fast - reads pre-calculated)
source("R/analysis/fii_analysis.R")
get_fii_score("HGLG11")
```

---

**Status:** ✅ Production Ready
**Architecture:** v2.0.0 (Refactored)
**Performance:** 400-600x faster analysis

🚀 **Start analyzing now!**
