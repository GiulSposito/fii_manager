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

---

## 🆕 Advanced Analysis (v3.0) ⭐ NEW!

### 1. Individual FII Deep Analysis (7 Sections)

**File:** `fii_individual_analysis.R`

Comprehensive analysis framework for individual FII evaluation with 7 detailed sections.

```r
source("R/analysis/fii_individual_analysis.R")

# Analyze single FII
analysis <- analyze_fii_deep("HGLG11")

# Print formatted analysis
print_fii_analysis(analysis)
```

**7 Analysis Sections:**

1. **Perfil do FII** - Basic profile (segment, PL, cotistas, governance)
2. **Análise de Qualidade** - Quality metrics with deep indicators
   - Block A score breakdown
   - Alavancagem (leverage)
   - Concentração de cotistas
   - Estabilidade patrimônio
   - Taxa de eficiência
3. **Análise de Renda** - Income analysis
   - DY 12m, crescimento, consistência
   - Histórico de proventos (últimos 12 meses)
   - Volatilidade de DY
4. **Análise de Valuation** - Valuation metrics
   - P/VP atual vs histórico
   - Preço justo estimado
   - Desconto/prêmio
   - Z-score P/VP vs segmento
5. **Análise de Risco** - Risk assessment
   - Volatilidade
   - Maximum drawdown
   - Estabilidade de rentabilidade
   - Risk score breakdown
6. **Cenários e Projeções** - Scenario modeling
   - Best case
   - Base case
   - Worst case
   - Probabilidades e drivers
7. **Pontos de Atenção / Alertas** - Warning flags
   - Red flags (critical issues)
   - Yellow flags (watch closely)
   - Green flags (positive indicators)

**Usage Example:**

```r
# Analyze FII
analysis <- analyze_fii_deep("KNRI11")

# Access specific sections
analysis$perfil       # Basic profile
analysis$qualidade    # Quality analysis
analysis$renda        # Income analysis
analysis$valuation    # Valuation
analysis$risco        # Risk
analysis$cenarios     # Scenarios
analysis$alertas      # Alerts

# Export to markdown (requires pipeline v3.0 with reports)
source("R/pipeline/main_complete_pipeline.R")
run_complete_analysis(
  tickers = c("KNRI11"),
  include_analysis = TRUE,
  include_reports = TRUE
)
# Output: reports/YYYY-MM-DD/KNRI11_analysis.md
```

**Performance:**
- ~5 seconds per FII
- Uses cache for optimal speed

---

### 2. Advanced Opportunities Search

**File:** `fii_opportunities.R` ⭐ NEW v3.0

Multi-criteria opportunity finder with advanced ranking and classification.

```r
source("R/analysis/fii_opportunities.R")

# Advanced search with user profile
opportunities <- identify_opportunities(
  scores = readRDS("data/fii_scores_enriched.rds"),
  user_profile = list(
    risk_tolerance = "moderate",      # low, moderate, high
    preferred_segments = c("Logística", "Lajes Corporativas"),
    min_liquidity = 1000000,          # R$ 1M/day
    investment_horizon = "long"       # short, medium, long
  ),
  min_score = 65,
  min_dy = 0.10,
  max_pvp = 1.1
)

# View top opportunities
opportunities$top_opportunities %>%
  head(10) %>%
  select(ticker, total_score, dy_12m, pvp, opportunity_type, score_justification)
```

**Features:**

- **Multi-criteria filtering:** Score, DY, P/VP, liquidez, segmento
- **User profile matching:** Adapts to risk tolerance and preferences
- **Opportunity classification:**
  - `value` - Undervalued (low P/VP, high quality)
  - `growth` - Growth potential (high momentum, improving metrics)
  - `income` - Income-focused (high DY, consistent distributions)
  - `hybrid` - Balanced opportunities
- **Advanced ranking:** Considers multiple factors weighted by profile
- **Justification:** Each opportunity includes reasoning

**Functions:**

| Function | Purpose |
|----------|---------|
| `identify_opportunities()` | Main search function |
| `filter_by_score()` | Score-based filtering |
| `filter_by_segment()` | Segment filtering |
| `filter_by_user_profile()` | Profile matching |
| `rank_opportunities()` | Advanced ranking |
| `classify_opportunity_type()` | Type classification |
| `generate_opportunity_summary()` | Summary report |

**Example Use Cases:**

```r
# Value investing (buy undervalued quality FIIs)
value_opps <- identify_opportunities(
  user_profile = list(
    risk_tolerance = "moderate",
    investment_horizon = "long"
  ),
  min_score = 70,
  max_pvp = 0.90,  # At least 10% discount
  min_dy = 0.08
)

value_opps$top_opportunities %>%
  filter(opportunity_type == "value")

# Income investing (maximize dividend yield)
income_opps <- identify_opportunities(
  user_profile = list(
    risk_tolerance = "low",
    investment_horizon = "medium"
  ),
  min_score = 60,
  min_dy = 0.12,  # High yield
  max_pvp = 1.0
)

income_opps$top_opportunities %>%
  filter(opportunity_type == "income")

# Growth investing (momentum + improving fundamentals)
growth_opps <- identify_opportunities(
  user_profile = list(
    risk_tolerance = "high",
    preferred_segments = c("Logística", "Data Centers"),
    investment_horizon = "long"
  ),
  min_score = 65
)

growth_opps$top_opportunities %>%
  filter(opportunity_type == "growth") %>%
  filter(!is.na(momentum_12m), momentum_12m > 0)
```

---

### 3. Integrated Complete Analysis

**File:** `main_complete_pipeline.R` (Phase 6-7)

Pipeline v3.0 integrates analysis and report generation.

```r
source("R/pipeline/main_complete_pipeline.R")

# Run complete analysis (all phases)
result <- run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",
  include_cvm = TRUE,
  include_deep_indicators = TRUE,
  include_analysis = TRUE,      # ⭐ Individual analysis
  include_reports = TRUE         # ⭐ Markdown reports
)

# Generated files:
# - data/fii_analyses_YYYYMMDD.rds
# - reports/YYYY-MM-DD/TICKER_analysis.md (per FII)
# - reports/YYYY-MM-DD/opportunities_summary.md
```

**Integrated workflow:**

1. **Phase 1-5:** Data collection → Validation → Scoring → Deep indicators → Persist
2. **Phase 6:** Individual FII analysis (7 sections per FII)
3. **Phase 7:** Markdown report generation

**Benefits:**
- One-command complete analysis
- Consistent data across all analyses
- Automated report generation
- Batch processing for multiple FIIs

---

## 🎯 Workflow Comparison

### v2.0 Workflow (Fast Queries)

```r
# 1. Run pipeline
source("R/pipeline/main_portfolio_with_scoring.R")

# 2. Instant analysis
source("R/analysis/fii_analysis.R")
print_portfolio_summary()
opportunities <- find_opportunities(min_score = 70)
```

**Best for:** Daily portfolio review, quick filtering, market scanning

---

### v3.0 Workflow (Deep Analysis)

```r
# 1. Run complete pipeline
source("R/pipeline/main_complete_pipeline.R")
result <- run_complete_analysis(
  include_analysis = TRUE,
  include_reports = TRUE
)

# 2. Deep individual analysis
source("R/analysis/fii_individual_analysis.R")
analysis <- analyze_fii_deep("HGLG11")
print_fii_analysis(analysis)

# 3. Advanced opportunities
source("R/analysis/fii_opportunities.R")
opportunities <- identify_opportunities(
  user_profile = list(risk_tolerance = "moderate"),
  min_score = 65
)
```

**Best for:** Monthly deep dive, investment research, buy/sell decisions

---

## 🔄 Integration Examples

### Example 1: Complete Monthly Analysis

```r
# Month-end complete analysis
source("R/pipeline/main_complete_pipeline.R")

result <- run_complete_analysis(
  mode = "full",
  tickers = "all",
  include_cvm = TRUE,
  include_deep_indicators = TRUE,
  include_analysis = TRUE,
  include_reports = TRUE
)

# Review generated reports
reports <- list.files("reports", recursive = TRUE, pattern = "\\.md$")
cat(glue("Generated {length(reports)} reports\n"))

# Load analyses for further processing
analyses <- readRDS(result$phase_results$analysis$output_file)

# Extract specific insights
top_quality <- analyses %>%
  map_dfr(~tibble(
    ticker = .x$ticker,
    quality_score = .x$qualidade$score,
    quality_rank = .x$qualidade$rank
  )) %>%
  arrange(desc(quality_score)) %>%
  head(10)
```

---

### Example 2: Portfolio Deep Dive

```r
# Analyze all portfolio holdings deeply
source("R/analysis/fii_individual_analysis.R")

portfolio <- readRDS("data/portfolio.rds")
tickers <- unique(portfolio$ticker)

# Deep analysis for each
analyses <- map(tickers, analyze_fii_deep)
names(analyses) <- tickers

# Find concerning holdings
concerns <- analyses %>%
  keep(~length(.x$alertas$red_flags) > 0)

cat(glue("⚠️ {length(concerns)} holdings with red flags\n"))

# Review concerns
for (ticker in names(concerns)) {
  cat(glue("\n{ticker}:\n"))
  print(concerns[[ticker]]$alertas$red_flags)
}
```

---

### Example 3: Research Workflow

```r
# 1. Find opportunities
source("R/analysis/fii_opportunities.R")
opportunities <- identify_opportunities(min_score = 70)

# 2. Deep dive top 3
source("R/analysis/fii_individual_analysis.R")
top_3 <- opportunities$top_opportunities$ticker[1:3]

analyses <- map(top_3, analyze_fii_deep)
names(analyses) <- top_3

# 3. Compare with portfolio holdings
source("R/analysis/fii_comparison.R")
comparisons <- map(top_3, ~compare_with_peers(.x, max_peers = 5))

# 4. Decision support
for (ticker in top_3) {
  cat(glue("\n{'='*60}\n"))
  cat(glue("RESEARCH: {ticker}\n"))
  cat(glue("{'='*60}\n\n"))

  # Análise
  print_fii_analysis(analyses[[ticker]])

  # Comparação
  cat("\n--- PEER COMPARISON ---\n")
  print_comparison_report(comparisons[[ticker]])
}
```

---

## 📚 Documentation Links

### v2.0 (Fast Queries)
- `fii_analysis.R` - Portfolio and opportunity functions
- `fii_comparison.R` - Peer comparison functions
- `analysis_examples.R` - Usage examples

### v3.0 (Deep Analysis) ⭐ NEW
- `fii_individual_analysis.R` - Individual FII deep analysis (7 sections)
- `fii_opportunities.R` - Advanced opportunity search
- [`../docs/pipeline_v3_usage.md`](../docs/pipeline_v3_usage.md) - Pipeline v3.0 guide
- [`../docs/TUTORIAL_COMPLETE_ANALYSIS.md`](../docs/TUTORIAL_COMPLETE_ANALYSIS.md) - Complete tutorial
- [`../docs/FAQ_PIPELINE_V3.md`](../docs/FAQ_PIPELINE_V3.md) - FAQ

---

**Last Updated:** 2026-03-21
**Version:** 2.0.0 (v3.0 Advanced Analysis Added)
**Status:** ✅ Production Ready
