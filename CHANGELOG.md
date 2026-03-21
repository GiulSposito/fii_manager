# Changelog

All notable changes to the FII Manager project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [3.0.0] - 2026-03-21

### 🎯 Pipeline Completo de 7 Fases - ORQUESTRADOR INTEGRADO

Major release introducing complete pipeline orchestration with 7 integrated phases, 15 new deep indicators, and advanced analysis capabilities.

### Added

#### Core Pipeline (7 Phases)

- **`R/pipeline/main_complete_pipeline.R`** - Complete pipeline orchestrator integrating all 7 phases
  - Phase 1: IMPORT (hybrid pipeline + CVM data)
  - Phase 2: CLEAN (validation with 4 levels)
  - Phase 3: TRANSFORM (basic scoring - 11 indicators)
  - Phase 4: DEEP (15 advanced indicators)
  - Phase 5: PERSIST (auto-backup + exports)
  - Phase 6: ANALYSIS (individual FII analysis - optional)
  - Phase 7: REPORT (markdown report generation - optional)

#### Deep Indicators (15 New Indicators)

- **`R/transform/fii_deep_indicators.R`** - Advanced multi-factor indicators

**Quality Indicators (4):**
- `calc_alavancagem()` - Leverage ratio from CVM data (passivo/PL)
- `calc_concentracao_cotistas()` - Shareholder concentration risk
- `calc_estabilidade_patrimonio()` - Equity stability (12-month CV)
- `calc_taxa_eficiencia()` - Management efficiency ratio

**Temporal Indicators (6):**
- `calc_momentum_3m()` - 3-month momentum
- `calc_momentum_6m()` - 6-month momentum
- `calc_momentum_12m()` - 12-month momentum
- `calc_trend_score()` - Trend analysis (growth trajectory)
- `calc_volatilidade_dy()` - Dividend yield volatility
- `calc_volatilidade_rentabilidade()` - Return volatility

**Relative Indicators (5):**
- `calc_zscore_dy_segmento()` - Z-score DY vs segment
- `calc_zscore_pvp_segmento()` - Z-score P/VP vs segment
- `calc_percentil_segmento()` - Percentile rank within segment
- `calc_relative_strength()` - Relative strength vs market
- `calc_peer_comparison_score()` - Score vs peers

**Consolidation:**
- `enrich_scores_with_deep_indicators()` - Main enrichment function
- `load_deep_indicators_cache()` - Cache management for performance

#### CVM Data Integration

- **`R/import/fii_cvm_data.R`** - CVM official fundamental data collector
  - Collects patrimonio_liquido, numero_cotistas, tx_administracao
  - Supports incremental updates (monthly refresh)
  - Automatic CNPJ mapping with fallback strategies
  - Cache-enabled (30-day TTL)

- **`R/validators/cvm_validator.R`** - CVM-specific validation suite
  - `validate_cvm_schema()` - Structure validation (17 required fields)
  - `validate_cvm_ranges()` - Numeric range checks
  - `validate_cvm_consistency()` - Cross-source validation vs Lupa/quotations
  - `validate_cvm_completeness()` - Coverage and missing data checks
  - `validate_cvm_all()` - Complete validation orchestration

#### Individual FII Analysis

- **`R/analysis/fii_individual_analysis.R`** - Deep analysis framework (7 sections)
  1. **Perfil do FII** - Basic profile (segment, PL, cotistas)
  2. **Análise de Qualidade** - Quality metrics with deep indicators
  3. **Análise de Renda** - Income analysis (proventos, consistency, growth)
  4. **Análise de Valuation** - Valuation metrics (P/VP, fair price, discount)
  5. **Análise de Risco** - Risk assessment (volatility, drawdown, stability)
  6. **Cenários e Projeções** - Scenario modeling (best/base/worst cases)
  7. **Pontos de Atenção** - Alerts and warnings

  Functions:
  - `analyze_fii_deep()` - Main analysis function
  - `print_fii_analysis()` - Formatted console output
  - `load_analysis_cache()` - Cache helper for performance
  - Helper builders for each section (7 functions)

#### Opportunities Search

- **`R/analysis/fii_opportunities.R`** - Advanced opportunity finder
  - `identify_opportunities()` - Multi-criteria search with ranking
  - `filter_by_score()` - Score-based filtering
  - `filter_by_segment()` - Segment filtering
  - `filter_by_user_profile()` - User profile matching
  - `rank_opportunities()` - Advanced ranking algorithms
  - `classify_opportunity_type()` - Classification (value, growth, income, hybrid)
  - `generate_opportunity_summary()` - Summary report generation

#### Documentation

- **`docs/pipeline_v3_usage.md`** - Complete pipeline v3.0 usage guide
- **`docs/TUTORIAL_COMPLETE_ANALYSIS.md`** - Step-by-step tutorial from installation to first analysis
- **`docs/MIGRATION_V2_TO_V3.md`** - Migration guide from v2.0 to v3.0
- **`docs/FAQ_PIPELINE_V3.md`** - FAQ, troubleshooting, and performance tips
- **`docs/deep_indicators_implementation.md`** - Technical details of deep indicators
- **`docs/deep_indicators_quickstart.md`** - Quick reference for deep indicators

#### Testing

- **`tests/test_pipeline_v3_e2e.R`** - End-to-end pipeline test covering all 7 phases
  - Phase validation (import, clean, transform, deep, persist, analysis, report)
  - Data integrity checks (schemas, ranges, consistency)
  - Output validation (files, formats, contents)
  - Error handling and recovery
  - Performance benchmarks

#### Data Files

New data files generated by v3.0 pipeline:

- `data/fii_cvm.rds` - CVM fundamental data
- `data/fii_scores_enriched.rds` - Scores with 15 deep indicators
- `data/fii_scores_enriched.csv` - CSV export (enriched scores)
- `data/fii_analyses_YYYYMMDD.rds` - Individual FII analyses
- `data/pipeline_metadata.rds` - Pipeline execution metadata
- `data_backup/fii_scores_*_YYYYMMDD_HHMMSS.rds` - Timestamped backups
- `reports/YYYY-MM-DD/TICKER_analysis.md` - Individual FII markdown reports
- `reports/YYYY-MM-DD/opportunities_summary.md` - Opportunities report

### Enhanced

#### Architecture

- **8-layer architecture** (was 3 layers in v2.0):
  1. Import (enhanced with CVM)
  2. Clean (NEW - 4-level validation)
  3. Transform (basic scoring)
  4. Deep (NEW - advanced indicators)
  5. Persist (NEW - auto-backup)
  6. Analysis (enhanced - 7 sections per FII)
  7. Opportunities (NEW - advanced search)
  8. Report (NEW - markdown generation)

#### Pipeline Features

- **Configurable execution modes**:
  - `mode = "full"` - Complete refresh (monthly)
  - `mode = "incremental"` - Fast update (daily)

- **Flexible ticker selection**:
  - `tickers = "all"` - All available FIIs
  - `tickers = "portfolio"` - Portfolio FIIs only
  - `tickers = c("KNRI11", ...)` - Specific tickers

- **Optional phases**:
  - `include_cvm` - Toggle CVM data collection
  - `include_deep_indicators` - Toggle advanced indicators
  - `include_analysis` - Toggle individual analysis
  - `include_reports` - Toggle report generation

#### Analysis Capabilities

- **Individual FII Analysis** - 7-section comprehensive analysis per FII
- **Peer Comparison** - Segment benchmarking with z-scores
- **Opportunities Search** - Multi-criteria filtering with advanced ranking
- **Portfolio Summary** - Enhanced with deep indicators
- **Score Tracking** - Historical score changes with momentum analysis

#### Validation

- **4-level validation framework**:
  1. Schema (structure, types, required fields)
  2. Ranges (min/max bounds, outlier detection)
  3. Consistency (cross-source validation)
  4. Completeness (coverage, missing data analysis)

#### Performance

- **Pipeline execution time**:
  - Full mode with CVM: ~12 minutes
  - Incremental mode: ~2 minutes
  - Deep indicators enrichment: ~1 minute
  - Individual analysis: ~5 seconds per FII

- **Analysis remains fast** (from v2.0):
  - Portfolio analysis: <1 second
  - Opportunities search: <1 second
  - Peer comparison: <1 second

### Changed

#### Breaking Changes

None. v3.0 is fully backward compatible with v2.0 workflows.

#### Improvements

- **Backup system** - Automatic timestamped backups before overwrites
- **Export formats** - Added CSV export alongside RDS for enriched scores
- **Logging** - Enhanced structured logging with phase tracking
- **Error handling** - Graceful degradation if optional phases fail
- **Cache management** - Unified cache loading for analysis functions
- **Metadata tracking** - Execution metadata for audit trail

### Migration Notes

For users upgrading from v2.0:

1. **No breaking changes** - All v2.0 workflows continue to work
2. **New functions available** - Can be adopted incrementally
3. **New data files** - Additional RDS files created (fii_cvm.rds, fii_scores_enriched.rds)
4. **CVM data optional** - Pipeline works without CVM data (some deep indicators will be NA)
5. **Analysis optional** - Can run pipeline without analysis/reports for faster execution

See [`docs/MIGRATION_V2_TO_V3.md`](docs/MIGRATION_V2_TO_V3.md) for detailed migration guide.

### Dependencies

New dependencies in v3.0:

- No new package dependencies (uses existing tidyverse stack)
- CVM data requires internet connection for initial download
- Deep indicators require CVM data for full functionality

---

## [2.0.0] - 2026-03-20

### 🎯 Framework de Análise Multifatorial - 100% IMPLEMENTADO

Major release introducing multi-factor scoring framework, 600x faster analysis, and proper pipeline architecture.

### Added

#### Scoring Framework

- **`R/transform/fii_score_pipeline.R`** - Main scoring orchestrator
- **`R/transform/fii_scoring.R`** - 4-block scoring system (0-100 scale)
  - Block A: Quality (25%) - Liquidez, gestão, vacância
  - Block B: Income (30%) - DY, crescimento, consistência
  - Block C: Valuation (25%) - P/VP, preço justo
  - Block D: Risk (20%) - Volatilidade, concentração
- **`R/transform/fii_indicators.R`** - 11 core indicators
- **`R/transform/fii_data_sources.R`** - Data consolidation

#### Analysis Tools

- **`R/analysis/fii_analysis.R`** - Portfolio analysis and opportunities
- **`R/analysis/fii_comparison.R`** - Peer comparison
- **`R/analysis/analysis_examples.R`** - Usage examples

#### Pipeline

- **`R/pipeline/main_portfolio_with_scoring.R`** - Complete pipeline (import + scoring)

#### Data Files

- `data/fii_scores.rds` - Pre-calculated scores
- `data/fii_scores_history.rds` - Historical score tracking
- `data/fii_scores.csv` - CSV export

### Enhanced

- **Architecture refactoring** - Clean 3-layer architecture:
  1. Import (data collection)
  2. Transform (scoring)
  3. Analysis (queries)

- **Performance** - 400-1200x faster analysis:
  - Portfolio analysis: 2 min → 0.2s
  - Find opportunities: 2 min → 0.3s
  - Peer comparison: 4 min → 0.2s

- **Documentation** - Extensive documentation added:
  - `QUICKSTART.md`
  - `QUICKSTART_ANALYSIS.md`
  - `R/analysis/README.md`
  - `R/transform/README.md`

---

## [1.5.0] - 2026-03-20

### 🚀 Pipeline Híbrido - 100% IMPLEMENTADO

### Added

#### Hybrid Pipeline

- **`R/pipeline/hybrid_pipeline.R`** - Hybrid data collection orchestrator
- **`R/collectors/collector_base.R`** - Base collector class
- **`R/collectors/statusinvest_income_collector.R`** - StatusInvest income (60x faster)
- **`R/collectors/statusinvest_indicators_collector.R`** - StatusInvest indicators
- **`R/collectors/fiiscom_lupa_collector.R`** - Lupa metadata
- **`R/collectors/yahoo_prices_collector.R`** - Yahoo Finance prices

#### Validators

- **`R/validators/schema_validator.R`** - RDS structure validation
- **`R/validators/quality_validator.R`** - Data quality checks
- **`R/validators/consistency_validator.R`** - Cross-source consistency

#### Utilities

- **`R/utils/http_client.R`** - HTTP client with retries
- **`R/utils/parsers.R`** - Brazilian number/date parsers
- **`R/utils/logging.R`** - Structured logging
- **`R/utils/persistence.R`** - Incremental persistence

### Enhanced

- **Performance** - 3.75x faster pipeline:
  - Total: 45 min → 12 min
  - Income: 30 min → 30 sec (60x)

- **Reliability** - 8x more reliable:
  - Auth failures: 40% → <5%

---

## [1.0.0] - 2023

### Initial Release

- Basic portfolio management
- Web scraping from fiis.com.br
- Google Sheets integration
- Manual analysis scripts
- Legacy pipeline (pipeline2023.R)

---

## Version Naming

- **Major (X.0.0)** - Architecture changes, new major features
- **Minor (1.X.0)** - New features, backward compatible
- **Patch (1.0.X)** - Bug fixes, minor improvements

## Links

- [README](README.md) - Project overview
- [docs/pipeline_v3_usage.md](docs/pipeline_v3_usage.md) - Pipeline v3.0 usage
- [docs/MIGRATION_V2_TO_V3.md](docs/MIGRATION_V2_TO_V3.md) - Migration guide
- [docs/FAQ_PIPELINE_V3.md](docs/FAQ_PIPELINE_V3.md) - FAQ and troubleshooting
