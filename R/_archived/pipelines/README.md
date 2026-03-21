# Archived Pipelines

This directory contains historical pipeline implementations that have been superseded by the current v3.0 architecture.

## Pipeline Evolution History

### v1.0 - pipeline2020.R (2020)
- **Status:** Obsolete
- **Description:** Initial simple pipeline for portfolio updates
- **Features:** Basic portfolio import and price updates from Yahoo Finance
- **Superseded by:** pipeline2023.R

### v2.0 - pipeline2023.R (2023)
- **Status:** Obsolete
- **Description:** Enhanced pipeline with proventos (income distributions) scraping
- **Features:**
  - Portfolio import from Google Sheets
  - Price quotes from Yahoo Finance
  - Income distributions from fiis.com.br
- **Superseded by:** main_complete_pipeline.R (v3.0)

### main_portfolio.R
- **Status:** Obsolete (stub)
- **Description:** Simple stub wrapper for legacy compatibility
- **Features:** Minimal wrapper calling newer pipeline functions
- **Superseded by:** main_complete_pipeline.R (v3.0)

### main_prospect.R
- **Status:** Alternative/Experimental
- **Description:** Experimental pipeline focused on prospecting new FIIs
- **Features:**
  - Focus on market-wide analysis rather than portfolio
  - Alternative data collection approach
- **Note:** Not integrated into main pipeline, kept for reference

---

## Current Production Pipeline

**Location:** `R/pipeline/main_complete_pipeline.R`

**Version:** v3.0.0

**Features:**
- Complete data import from multiple sources (Yahoo, StatusInvest, Lupa, CVM)
- Advanced scoring system with 15+ indicators
- Deep fundamental analysis with 20+ metrics
- Comprehensive validation (schema, quality, consistency)
- External portfolio comparison (Empiricus and others)
- Automated backup and error recovery

**Usage:**
```r
source("R/pipeline/main_complete_pipeline.R")
```

---

## Migration Notes

If you need to understand the progression from older versions to v3.0, see:
- `docs/_archived/MIGRATION_V2_TO_V3.md` - Detailed migration guide
- `docs/PIPELINE_V3_QUICKREF.md` - Quick reference for v3.0
- `CHANGELOG.md` - Complete change history

---

**Last Updated:** 2026-03-21
**Archived By:** Repository reorganization
