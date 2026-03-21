# Pipeline v3.0 - Guia de Uso

## Visão Geral

O Pipeline v3.0 (`R/pipeline/main_complete_pipeline.R`) é o orquestrador completo do sistema de análise de FIIs, integrando todas as fases desde coleta até geração de relatórios.

## Arquitetura em 7 Fases

### FASE 1: IMPORT (Coleta de Dados)
- Executa `hybrid_pipeline` (collectors existentes: StatusInvest, Lupa, Yahoo, Portfolio)
- Coleta dados CVM (opcional, dados fundamentalistas oficiais)
- Output: `data/*.rds` (portfolio, income, quotations, fiis, fii_cvm)

### FASE 2: CLEAN (Validação)
- Valida estrutura e integridade dos arquivos RDS
- Valida dados CVM (schema, ranges, consistência, completude)
- Output: logs e relatórios de validação

### FASE 3: TRANSFORM (Scoring Básico)
- Executa `run_scoring_pipeline()` (11 indicadores, 4 blocos)
- Calcula scores para todos os FIIs
- Output: `data/fii_scores.rds`, `data/fii_scores_history.rds`

### FASE 4: DEEP INDICATORS (Indicadores Avançados)
- Enriquece scores com 8+ indicadores avançados:
  - **Qualidade**: alavancagem, concentração cotistas, estabilidade patrimônio, taxa eficiência
  - **Temporal**: momentum (3m, 6m, 12m), trend score, volatilidade (DY, rentabilidade)
  - **Relativo**: z-scores vs segmento, percentis, relative strength
- Output: `data/fii_scores_enriched.rds`

### FASE 5: PERSIST (Persistência)
- Backup de arquivos existentes
- Salva scores enriquecidos (RDS + CSV)
- Salva metadados da execução
- Output: backups em `data_backup/`, arquivos finais em `data/`

### FASE 6: ANALYSIS (Análise Individual - Opcional)
- Executa análise profunda para cada FII selecionado
- Usa `analyze_fii_deep()` de `fii_individual_analysis.R`
- Output: `data/fii_analyses_YYYYMMDD.rds`

### FASE 7: REPORT (Relatórios - Opcional)
- Gera relatórios markdown individuais por FII
- Gera relatório de oportunidades consolidado
- Output: `reports/YYYY-MM-DD/*.md`

## Uso Básico

### Execução Completa (Full Refresh)

```r
source("R/pipeline/main_complete_pipeline.R")

result <- run_complete_analysis(
  mode = "full",              # Atualização completa
  tickers = "all",            # Todos os FIIs disponíveis
  include_cvm = TRUE,         # Coleta dados CVM
  include_deep_indicators = TRUE,  # Calcula indicadores avançados
  include_analysis = FALSE,   # Pula análise individual (rápido)
  include_reports = FALSE,    # Pula relatórios
  log_level = "INFO"
)
```

### Execução Incremental (Atualização Rápida)

```r
result <- run_complete_analysis(
  mode = "incremental",       # Atualização incremental
  tickers = "portfolio",      # Apenas portfolio
  include_cvm = FALSE,        # Pula CVM (já coletado)
  include_deep_indicators = TRUE,
  log_level = "INFO"
)
```

### Análise Profunda com Relatórios

```r
result <- run_complete_analysis(
  mode = "incremental",
  tickers = c("KNRI11", "MXRF11", "VISC11"),  # FIIs específicos
  include_cvm = TRUE,
  include_deep_indicators = TRUE,
  include_analysis = TRUE,    # Análise individual
  include_reports = TRUE,     # Gera relatórios markdown
  log_level = "DEBUG"
)
```

## Parâmetros

### mode
- `"full"`: Refresh completo, força recálculo de todos os dados
- `"incremental"`: Atualização incremental, usa cache quando possível

### tickers
- `"all"`: Todos os FIIs disponíveis (fiis.rds + portfolio.rds)
- `"portfolio"`: Apenas FIIs no portfolio (portfolio.rds)
- `c("KNRI11", "MXRF11", ...)`: Lista específica de tickers

### include_cvm
- `TRUE`: Coleta dados fundamentalistas da CVM (recomendado 1x por mês)
- `FALSE`: Pula coleta CVM (dados já existentes)

### include_deep_indicators
- `TRUE`: Calcula indicadores avançados (alavancagem, momentum, z-scores)
- `FALSE`: Apenas indicadores básicos (11 originais)

### include_analysis
- `TRUE`: Executa análise profunda individual por FII (lento)
- `FALSE`: Apenas calcula scores (rápido)

### include_reports
- `TRUE`: Gera relatórios markdown (requer `include_analysis = TRUE`)
- `FALSE`: Pula geração de relatórios

### log_level
- `"DEBUG"`: Logs muito detalhados
- `"INFO"`: Logs informativos (padrão)
- `"WARN"`: Apenas warnings e erros
- `"ERROR"`: Apenas erros

## Output

### Estrutura do Resultado

```r
result <- list(
  phase_results = list(
    import = list(hybrid = ..., cvm = ...),
    clean = list(validation_results),
    transform = tibble(basic_scores),
    deep = tibble(enriched_scores),
    persist = list(backups, files),
    analysis = list(analyses, num_success, num_failed),
    report = list(reports_dir, report_paths)
  ),
  metadata = list(
    pipeline_version = "3.0.0",
    execution_date = <timestamp>,
    mode = "full"|"incremental",
    num_fiis = <count>
  ),
  summary = list(
    overall_success = TRUE|FALSE,
    completed_phases = c("import", "clean", ...),
    failed_phases = c(...),
    total_duration_secs = <seconds>
  ),
  errors = list(...)
)
```

### Arquivos Gerados

**Dados:**
- `data/fii_scores.rds` - Scores básicos
- `data/fii_scores_enriched.rds` - Scores + deep indicators
- `data/fii_scores_enriched.csv` - Export CSV
- `data/fii_cvm.rds` - Dados CVM (se `include_cvm = TRUE`)
- `data/pipeline_metadata.rds` - Metadados da execução

**Análises (se habilitado):**
- `data/fii_analyses_YYYYMMDD.rds` - Análises individuais

**Relatórios (se habilitado):**
- `reports/YYYY-MM-DD/<TICKER>_analysis.md` - Relatórios por FII
- `reports/YYYY-MM-DD/opportunities_summary.md` - Resumo de oportunidades

**Logs:**
- `data/.logs/pipeline_YYYYMMDD_HHMMSS.log` - Log estruturado da execução

**Backups:**
- `data_backup/fii_scores_YYYYMMDD_HHMMSS.rds` - Backups automáticos

## Integração com Outros Scripts

### Carregar Scores Enriquecidos

```r
# Carregar último resultado
scores <- readRDS("data/fii_scores_enriched.rds")

# Verificar deep indicators
names(scores)  # Ver todas as colunas

# Filtrar por recomendação
scores %>%
  filter(recommendation == "COMPRAR") %>%
  arrange(desc(total_score))
```

### Usar Análises

```r
# Carregar análises
analyses <- readRDS("data/fii_analyses_20260321.rds")

# Ver análise de um FII
analyses$KNRI11

# Extrair scores
scores_list <- map(analyses, ~.x$score)
```

### Verificar Metadados

```r
metadata <- readRDS("data/pipeline_metadata.rds")
metadata$execution_date
metadata$num_fiis
metadata$data_sources
```

## Troubleshooting

### Pipeline falha na FASE 1 (IMPORT)
- Verificar conexão internet
- Verificar credenciais Google Sheets (portfolio)
- Ver logs em `data/.logs/`

### CVM validation warnings
- Normal para alguns FIIs sem CNPJ mapping
- Adicionar mapping em `data/fii_cnpj_mapping.rds` se necessário

### Deep indicators com muitos NAs
- Verificar se `data/fii_cvm.rds` existe e tem dados
- Verificar se `data/fii_scores_history.rds` existe (momentum requer histórico)
- Executar pipeline em `mode = "full"` para rebuild do histórico

### Análise/relatórios lentos
- Normal - análise individual é detalhada
- Limitar tickers: `tickers = "portfolio"` ou lista específica
- Pular para execuções diárias: `include_analysis = FALSE`

## Recomendações de Uso

### Execução Diária (Rápida)
```r
run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",
  include_cvm = FALSE,
  include_deep_indicators = TRUE,
  include_analysis = FALSE,
  include_reports = FALSE
)
```

### Execução Semanal (Completa)
```r
run_complete_analysis(
  mode = "full",
  tickers = "all",
  include_cvm = FALSE,
  include_deep_indicators = TRUE,
  include_analysis = FALSE,
  include_reports = FALSE
)
```

### Execução Mensal (Full + CVM)
```r
run_complete_analysis(
  mode = "full",
  tickers = "all",
  include_cvm = TRUE,
  include_deep_indicators = TRUE,
  include_analysis = TRUE,
  include_reports = TRUE
)
```

## Monitoramento

Verificar logs em tempo real:
```bash
tail -f data/.logs/pipeline_*.log
```

Ver últimos erros:
```bash
grep "ERROR" data/.logs/pipeline_*.log | tail -20
```

## Dependências

O pipeline requer:
- `R/pipeline/hybrid_pipeline.R`
- `R/transform/fii_score_pipeline.R`
- `R/transform/fii_deep_indicators.R`
- `R/import/fii_cvm_data.R`
- `R/validators/cvm_validator.R`
- `R/analysis/fii_individual_analysis.R` (se `include_analysis = TRUE`)
- `R/analysis/fii_opportunities.R` (se `include_reports = TRUE`)
- `R/utils/logging.R`
- `R/utils/persistence.R`

Pacotes R:
- tidyverse
- lubridate
- glue
- yaml

## Próximos Passos

Após execução bem-sucedida:
1. Verificar scores em `data/fii_scores_enriched.rds`
2. Analisar oportunidades: `source("R/analysis/fii_opportunities.R")`
3. Gerar dashboards: `rmarkdown::render("R/dashboard/portfolio.Rmd")`
4. Explorar indicadores avançados com filtros custom

## Suporte

Para issues:
1. Verificar logs em `data/.logs/`
2. Verificar validação em phase_results$clean
3. Ver erros em result$errors
4. Verificar se arquivos base existem (portfolio.rds, fiis.rds)
