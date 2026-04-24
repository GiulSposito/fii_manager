# FII Analysis - Quick Start Guide

**Ready to use:** ✅ All scripts implemented and tested
**Last updated:** 2026-03-20

---

## 🚀 Get Started in 30 Seconds

### Option 1: Quick Test (Recommended First)

```r
# Test the system with one FII
source("R/analysis/fii_analysis_examples.R")
quick_test("HGLG11")
```

**What it does:** Tests all main functions and shows sample output

---

### Option 2: Score Your Portfolio

```r
# Score all FIIs in your portfolio
source("R/analysis/fii_score.R")
scores <- score_multiple_fiis("portfolio")
print_ranking(scores, top_n = 10)

# Save results
saveRDS(scores, "data/portfolio_scores.rds")
write_csv(scores, "data/portfolio_scores.csv")
```

**What it does:** Analyzes your entire portfolio and shows ranking

---

### Option 3: Analyze Single FII

```r
# Detailed analysis of one FII
source("R/analysis/fii_score.R")
score <- calculate_fii_score("HGLG11")
cat(format_score_report(score))
```

**What it does:** Complete breakdown with all indicators

---

## 📊 What You Get

### Score Breakdown (0-100)

- **Quality (25%)** - Governance, size, concentration
- **Income (30%)** - Dividend yield, stability, growth
- **Valuation (25%)** - P/VP, discount, yield spread
- **Risk (20%)** - Liquidity, volatility, drawdown

### Recommendations

- 🟢 **COMPRAR** (75-100) - Buy signal
- 🟡 **MANTER** (60-74) - Hold
- 🟠 **OBSERVAR** (40-59) - Watch
- 🔴 **EVITAR** (0-39) - Avoid

---

## 🎯 Common Use Cases

### 1. Find Best Opportunities

```r
source("R/analysis/fii_analysis_examples.R")

opportunities <- find_opportunities(
  min_score = 70,      # Minimum score
  min_dy = 8,          # Minimum dividend yield %
  max_pvp = 1.0        # Maximum P/VP ratio
)

print_ranking(opportunities)
```

---

### 2. Compare with Peers

```r
source("R/analysis/fii_comparison.R")

# Compare HGLG11 with similar FIIs
comparison <- compare_with_peers("HGLG11", max_peers = 5)
format_comparison_report(comparison)
```

---

### 3. Analyze Entire Segment

```r
source("R/analysis/fii_comparison.R")

# Analyze all "Lajes Corporativas" FIIs
scores <- analyze_segment("Lajes Corporativas", min_patrimonio = 100e6)
print_ranking(scores, top_n = 10)
```

---

### 4. Portfolio vs Market

```r
source("R/analysis/fii_comparison.R")

comparison <- portfolio_vs_market()

# See statistics
comparison$portfolio_stats
comparison$market_stats
```

---

## 📚 Full Documentation

For complete guide with all functions:
- **User guide:** `R/analysis/README.md`
- **Implementation details:** `docs/FII_ANALYSIS_STATUS.md`
- **Examples:** `R/analysis/fii_analysis_examples.R`

---

## ⚙️ Before You Start

### Update Your Data (Important!)

```r
# Run existing pipeline to get latest data
source("R/pipeline/pipeline2023.R")
```

**Why?** The analysis uses cached data from `data/*.rds` files.

---

## 🧪 Verify Installation

```r
# Check if all scripts load correctly
source("R/analysis/fii_data_sources.R")
source("R/analysis/fii_indicators.R")
source("R/analysis/fii_score.R")
source("R/analysis/fii_comparison.R")

# If no errors, you're good to go!
```

---

## 📈 Sample Output

```
🔴 BRCR11 - Score Total: 33.5/100

📊 Breakdown por Bloco:
  • Qualidade:  59.3/100
  • Renda:      23.3/100
  • Valuation:  28.2/100
  • Risco:      23.1/100

💰 Indicadores-Chave:
  • Preço atual: R$ 43,16
  • P/VP:        0,50
  • DY 12M:      5,9%

✅ Recomendação: EVITAR

📈 Tipo: Tijolo:Lajes Corporativas
🔍 Data Quality: 75%
```

---

## ⚡ Performance

- **Single FII:** 1-2 seconds
- **Portfolio (60 FIIs):** 1-2 minutes
- **With StatusInvest:** 5-8 seconds per FII (optional)

---

## 🔧 Customization

### Change Block Weights

```r
# Default: Quality=25%, Income=30%, Valuation=25%, Risk=20%

score <- calculate_fii_score(
  "HGLG11",
  weights = c(
    quality = 0.20,
    income = 0.40,     # More weight on income
    valuation = 0.25,
    risk = 0.15
  )
)
```

### Include StatusInvest Data

```r
# Slower but more complete
score <- calculate_fii_score(
  "HGLG11",
  include_statusinvest = TRUE
)
```

---

## 💡 Tips

1. **Data Quality:** Check `data_completeness` in results (should be > 0.75)
2. **Batch Processing:** Always better than individual calls
3. **Cache Results:** Save scores periodically to track changes
4. **Update Regularly:** Run data pipeline before analysis

---

## 🐛 Troubleshooting

### Error: "File not found"
**Solution:** Make sure you're in project root directory

### Low data completeness (<50%)
**Solution:** Update cache with `source("R/pipeline/pipeline2023.R")`

### StatusInvest fails
**Solution:** Don't worry, it's optional. System works without it.

---

## 📞 Need Help?

1. **Quick test fails?** Check `R/analysis/README.md`
2. **Want more examples?** See `R/analysis/fii_analysis_examples.R`
3. **Technical details?** Read `docs/FII_ANALYSIS_STATUS.md`

---

## 🎯 Next Steps After First Run

1. **Review your results** - Check which FIIs are underperforming
2. **Compare with peers** - See if scores are segment-specific
3. **Find opportunities** - Use filters to discover new FIIs
4. **Track over time** - Save scores weekly/monthly

---

## ✅ Ready?

**Start now:**

```r
source("R/analysis/fii_analysis_examples.R")
quick_test()
```

**Then explore:**

```r
# See all available examples
?run_all_examples

# Or run the complete demo
run_all_examples()
```

---

**Status:** ✅ Production Ready
**Version:** 1.0.0
**Date:** 2026-03-20

🚀 **Happy analyzing!**
