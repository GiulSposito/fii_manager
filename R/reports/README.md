# Portfolio Analysis Report Generator

**Created:** 2026-03-21
**Version:** 3.0.0
**Author:** Claude Code

## Overview

This module generates a comprehensive HTML portfolio analysis report with embedded visualizations for Brazilian Real Estate Investment Funds (FIIs).

## Files Created

### 1. `report_data_loader.R`
**Purpose:** Load and validate all required data files

**Functions:**
- `load_report_data()` - Load all CSV, RDS, and markdown files
- `validate_report_data()` - Validate data structure and completeness

**Data Sources:**
- `/tmp/portfolio_with_dividends.csv` - Portfolio with dividend metrics (61 FIIs)
- `/tmp/portfolio_final_summary.md` - Summary text
- `data/portfolio.rds` - Portfolio positions
- `data/fii_scores_enriched.rds` - FII scores with deep indicators
- `data/income.rds` - Income distributions history
- `data/quotations.rds` - Price quotes
- `data/portfolios/empiricus_renda.rds` - Empiricus Renda portfolio (optional)
- `data/portfolios/empiricus_tatica.rds` - Empiricus Tática portfolio (optional)

### 2. `report_data_transforms.R`
**Purpose:** Transform raw data into analysis-ready formats

**Functions:**
- `prepare_sector_allocation()` - Aggregate portfolio by sector
- `prepare_dividend_timeline()` - Monthly dividend aggregates with rolling averages
- `prepare_top_performers()` - Top N performers by total return
- `prepare_bottom_performers()` - Bottom N performers by total return
- `prepare_portfolio_summary()` - Overall portfolio metrics
- `prepare_score_distribution()` - Portfolio scores distribution
- `prepare_empiricus_comparison()` - Comparison metrics with Empiricus portfolios

### 3. `report_visualizations.R`
**Purpose:** Generate all charts for the report

**Functions:**
- `generate_sector_pie_chart()` - Sector allocation pie chart
- `generate_top_performers_bar()` - Top 10 performers bar chart
- `generate_bottom_performers_bar()` - Bottom 10 performers bar chart
- `generate_score_histogram()` - Score distribution histogram
- `generate_dividend_dual_bar()` - Invested vs Dividends comparison
- `generate_dividend_timeline()` - Monthly dividends with moving average
- `generate_concentration_treemap()` - Portfolio concentration treemap
- `generate_return_scatter()` - Return vs DY scatter plot
- `generate_empiricus_comparison()` - DY comparison bar chart
- `generate_score_radar()` - Score components radar chart

**Technology:**
- ggplot2 + theme_minimal() for static charts
- plotly for interactive visualizations
- Color gradient: red-yellow-green for performance

### 4. `report_styles.css`
**Purpose:** CSS styling for the HTML report

**Features:**
- Callout boxes (info, success, warning, danger)
- Responsive tables with hover effects
- Metric cards with gradients
- Professional color scheme
- Print-friendly styles
- Mobile responsive design

### 5. `portfolio_analysis_report.Rmd`
**Purpose:** RMarkdown report template

**Report Sections:**
1. Executive Summary
2. Alocação de Ativos (Asset Allocation)
3. Performance do Portfólio (Top/Bottom performers)
4. Análise de Dividendos (Dividend analysis)
5. Análise de Qualidade (Quality scores)
6. Concentração e Risco (Concentration analysis)
7. Retorno vs Dividend Yield
8. Comparação com Empiricus
9. Lições Aprendidas (Lessons learned)
10. Plano de Ação (Action plan - 3 phases)
11. Portfólio Alvo Recomendado (Target portfolio)
12. Resultado Esperado (Expected results)
13. Anexo: Posições Detalhadas (All positions)
14. Metodologia (Methodology)

**Output:**
- Self-contained HTML with embedded images/JS
- Floating table of contents
- Responsive design
- Interactive charts (plotly)

### 6. `generate_portfolio_report.R`
**Purpose:** Wrapper function to render the report

**Functions:**
- `generate_portfolio_report()` - Main rendering function
- `quick_report()` - Quick generation with defaults

**Usage:**
```r
source("R/reports/generate_portfolio_report.R")
generate_portfolio_report(
  output_file = "/tmp/portfolio_analysis_report.html",
  open_browser = TRUE
)

# Or quick version
quick_report()
```

## Generated Report Details

**File:** `/tmp/portfolio_analysis_report.html`
**Size:** 4.87 MB (under 5MB limit)
**Format:** Self-contained HTML with embedded assets
**Render Time:** ~3-6 seconds

**Contains:**
- 14 visualization charts (all interactive)
- 8 data tables with formatting
- Summary metrics with color-coded cards
- Complete action plan with checkboxes
- Empiricus comparison
- Methodology section

## Key Metrics Validated

✅ **Total Invested:** R$ 330,480
✅ **Total Dividends:** R$ 146,546
✅ **Total Return:** +11.81%
✅ **Number of FIIs:** 61 (active positions)

## Dependencies

**R Packages:**
- tidyverse (dplyr, tidyr, ggplot2, stringr, purrr)
- rmarkdown
- knitr
- kableExtra
- plotly
- scales
- glue
- lubridate
- zoo (for rolling averages)

All packages are already installed in the project environment.

## Reusable Components

The report modules are designed to be reusable:

```r
# Load data
source("R/reports/report_data_loader.R")
data <- load_report_data()

# Transform data
source("R/reports/report_data_transforms.R")
sector_data <- prepare_sector_allocation(data$scores, data$portfolio_csv)

# Generate visualizations
source("R/reports/report_visualizations.R")
chart <- generate_sector_pie_chart(sector_data)
chart  # Display in RStudio or browser
```

## Future Enhancements

Potential improvements:
1. Add benchmark comparison (IFIX, CDI)
2. Include technical indicators (RSI, MACD)
3. Add portfolio optimization recommendations
4. Generate monthly/quarterly reports automatically
5. Export to PDF option
6. Add comparison with previous reports (time series)
7. Include risk metrics (Sharpe ratio, max drawdown)

## Troubleshooting

If rendering fails:

1. **Check data files exist:**
   ```r
   file.exists("/tmp/portfolio_with_dividends.csv")
   file.exists("data/fii_scores_enriched.rds")
   ```

2. **Verify package installation:**
   ```r
   install.packages(c("rmarkdown", "knitr", "kableExtra", "plotly"))
   ```

3. **Check memory:**
   ```r
   gc()  # Garbage collection
   ```

4. **Enable debugging:**
   ```r
   knitr::opts_chunk$set(error = TRUE)  # Continue on errors
   ```

## Contact

For questions or issues, refer to:
- Main documentation: `CLAUDE.md`
- Pipeline documentation: `docs/pipeline_v3_usage.md`

---

**Report Generator v3.0** - Comprehensive Portfolio Analysis with Embedded Visualizations
