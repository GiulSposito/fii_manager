# FAQ - Pipeline v3.0

Perguntas frequentes, troubleshooting e dicas de performance para o Pipeline v3.0.

---

## 📋 Índice

- [Perguntas Gerais](#perguntas-gerais)
- [Execução e Performance](#execução-e-performance)
- [Dados e Indicadores](#dados-e-indicadores)
- [Erros Comuns](#erros-comuns)
- [Troubleshooting Avançado](#troubleshooting-avançado)
- [Performance Tips](#performance-tips)

---

## Perguntas Gerais

### Q: O que é o Pipeline v3.0?

**A:** Pipeline v3.0 é um orquestrador completo de 7 fases que integra:
- Coleta de dados (hybrid + CVM)
- Validação (4 níveis)
- Scoring (11 indicadores básicos)
- Deep indicators (15 indicadores avançados)
- Persistência (backup + export)
- Análise individual (7 seções por FII)
- Relatórios markdown

Tudo em uma única chamada: `run_complete_analysis()`.

---

### Q: Preciso migrar de v2.0 para v3.0?

**A:** Não necessariamente. v3.0 é **100% retrocompatível** com v2.0.

**Você pode:**
- Continuar usando v2.0: `main_portfolio_with_scoring.R` funciona normalmente
- Adotar v3.0 gradualmente: novos scripts não quebram workflows antigos
- Usar ambos: v2.0 para diário, v3.0 para análises profundas

**Recomendamos migrar se você quer:**
- Deep indicators (alavancagem, momentum, z-scores)
- Dados CVM oficiais
- Análise individual profunda
- Validação robusta em 4 níveis

Ver [Guia de Migração](MIGRATION_V2_TO_V3.md) para detalhes.

---

### Q: Quanto tempo demora o Pipeline v3.0?

**A:** Depende do modo e opções:

| Configuração | Tempo Estimado |
|--------------|----------------|
| Incremental, portfolio, sem CVM | ~2-3 min |
| Incremental, all tickers, sem CVM | ~3-4 min |
| Full, all tickers, com CVM | ~12-15 min |
| Full + análise individual (10 FIIs) | ~15-20 min |
| Full + análise + relatórios (50 FIIs) | ~30-40 min |

**Recomendação:**
- **Diário:** `mode = "incremental"`, `include_cvm = FALSE` (~3 min)
- **Mensal:** `mode = "full"`, `include_cvm = TRUE` (~15 min)

---

### Q: Qual a diferença entre `mode = "full"` e `mode = "incremental"`?

**A:**

**`mode = "full"`:**
- Força refresh completo de todos os dados
- Recalcula scores do zero
- Útil para rebuild mensal ou quando há inconsistências
- Mais lento (~12-15 min com CVM)

**`mode = "incremental"`:**
- Atualiza apenas dados novos
- Usa cache quando possível
- Ideal para execução diária
- Mais rápido (~2-3 min)

**Exemplo:**
```r
# Diário: rápido
run_complete_analysis(mode = "incremental", include_cvm = FALSE)

# Mensal: completo
run_complete_analysis(mode = "full", include_cvm = TRUE)
```

---

### Q: O que são "deep indicators"?

**A:** Deep indicators são 15 indicadores avançados adicionados na v3.0:

**Qualidade (4):**
- `alavancagem` - Leverage ratio (passivo/PL)
- `concentracao_cotistas` - Concentração de cotistas
- `estabilidade_patrimonio` - Estabilidade do patrimônio líquido
- `taxa_eficiencia` - Eficiência de gestão

**Temporal (6):**
- `momentum_3m`, `momentum_6m`, `momentum_12m` - Momentum de performance
- `trend_score` - Tendência de crescimento
- `volatilidade_dy` - Volatilidade do dividend yield
- `volatilidade_rentabilidade` - Volatilidade de rentabilidade

**Relativo (5):**
- `zscore_dy_segmento` - Z-score DY vs segmento
- `zscore_pvp_segmento` - Z-score P/VP vs segmento
- `percentil_segmento` - Percentil no segmento
- `relative_strength` - Força relativa
- `peer_comparison_score` - Score vs pares

**Requisitos:**
- Dados CVM (para indicadores de qualidade)
- Histórico de scores (para momentum)
- Dados de segmento (para z-scores)

---

## Execução e Performance

### Q: Como rodar apenas o básico (sem deep indicators)?

**A:**
```r
result <- run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",
  include_cvm = FALSE,
  include_deep_indicators = FALSE,  # Desabilita deep indicators
  include_analysis = FALSE,
  include_reports = FALSE
)
```

Isso executa apenas Import → Clean → Transform → Persist (~1-2 min).

---

### Q: Como rodar apenas para alguns FIIs específicos?

**A:**
```r
result <- run_complete_analysis(
  mode = "incremental",
  tickers = c("HGLG11", "KNRI11", "MXRF11"),  # Lista específica
  include_deep_indicators = TRUE
)
```

**Nota:** A fase de import ainda coleta dados de todos os FIIs (não é possível limitar), mas scoring e análise são aplicados apenas aos tickers especificados.

---

### Q: Como fazer execução silenciosa (sem logs no console)?

**A:**
```r
# Opção 1: Redirecionar output
sink("/dev/null")  # Linux/Mac
# sink("NUL")      # Windows
result <- run_complete_analysis(...)
sink()

# Opção 2: Usar log_level = "ERROR"
result <- run_complete_analysis(
  log_level = "ERROR"  # Apenas erros
)

# Opção 3: Capturar output
output <- capture.output({
  result <- run_complete_analysis(...)
})
```

Logs estruturados ainda são salvos em `data/.logs/`.

---

### Q: Como verificar se a execução foi bem-sucedida?

**A:**
```r
result <- run_complete_analysis(...)

# Verificar sucesso geral
result$summary$overall_success
# TRUE = sucesso, FALSE = falha

# Ver fases completadas
result$summary$completed_phases
# c("import", "clean", "transform", "deep", "persist")

# Ver erros (se houver)
result$errors
# list() se não houver erros

# Ver detalhes por fase
result$phase_results$import
result$phase_results$transform  # Tibble com scores
```

---

### Q: Pipeline está muito lento, como acelerar?

**A:** **Performance tips:**

1. **Desabilite CVM para execuções diárias:**
   ```r
   include_cvm = FALSE  # CVM só mensal
   ```

2. **Use `tickers = "portfolio"` em vez de `"all"`:**
   ```r
   tickers = "portfolio"  # Apenas seu portfolio
   ```

3. **Pule análise individual:**
   ```r
   include_analysis = FALSE  # Análise é lenta (~5s/FII)
   ```

4. **Use mode incremental:**
   ```r
   mode = "incremental"  # Usa cache
   ```

5. **Desabilite relatórios:**
   ```r
   include_reports = FALSE  # Relatórios são lentos
   ```

**Configuração otimizada para velocidade:**
```r
run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",
  include_cvm = FALSE,
  include_deep_indicators = TRUE,  # Rápido (~1 min)
  include_analysis = FALSE,
  include_reports = FALSE,
  log_level = "WARN"
)
# ~1-2 minutos
```

---

## Dados e Indicadores

### Q: Onde estão os dados gerados?

**A:** Pipeline v3.0 gera múltiplos arquivos:

**Dados principais:**
- `data/fii_scores.rds` - Scores básicos (v2.0 compatible)
- `data/fii_scores_enriched.rds` ⭐ - Scores + deep indicators
- `data/fii_cvm.rds` ⭐ - Dados CVM fundamentalistas
- `data/fii_scores_history.rds` - Histórico de scores

**Análises (se habilitado):**
- `data/fii_analyses_YYYYMMDD.rds` ⭐ - Análises individuais

**Relatórios (se habilitado):**
- `reports/YYYY-MM-DD/*.md` ⭐ - Relatórios markdown

**Metadata:**
- `data/pipeline_metadata.rds` ⭐ - Metadata de execução

**Backups:**
- `data_backup/*.rds` ⭐ - Backups automáticos

**Logs:**
- `data/.logs/pipeline_*.log` - Logs estruturados

---

### Q: Qual arquivo devo usar para análises?

**A:** Depende do que você precisa:

**Para análises v2.0 (compatibilidade):**
```r
scores <- readRDS("data/fii_scores.rds")
```

**Para análises v3.0 (recomendado):**
```r
scores <- readRDS("data/fii_scores_enriched.rds")
# Tem todos os indicadores v2.0 + 15 deep indicators
```

**Ambos têm:**
- Mesma estrutura base (ticker, total_score, recommendation)
- Mesma API para funções de análise

**Diferença:**
- `fii_scores_enriched.rds` tem colunas adicionais (deep indicators)
- Se você não usa deep indicators, ambos são equivalentes

---

### Q: Deep indicators têm muitos NAs, é normal?

**A:** Depende do contexto:

**Normal (esperado):**
- Indicadores de qualidade (alavancagem, concentração) requerem dados CVM
  - Se não rodou `include_cvm = TRUE`, terão NA
  - Se FII não tem dados CVM, terá NA
- Indicadores temporais (momentum) requerem histórico
  - Primeiras execuções terão NA (sem histórico)
  - Após 3-6 execuções, momentum será calculado
- Indicadores relativos (z-scores) requerem dados do segmento
  - FIIs sem segmento bem definido terão NA

**Anormal (investigar):**
- Todos os deep indicators são NA para todos os FIIs
  - Verificar se `include_deep_indicators = TRUE`
  - Verificar logs para erros

**Como reduzir NAs:**
```r
# 1. Coletar dados CVM
run_complete_analysis(include_cvm = TRUE)

# 2. Construir histórico (executar por vários dias)
# Momentum precisa de 3-12 meses de histórico

# 3. Verificar cobertura
scores <- readRDS("data/fii_scores_enriched.rds")

# % de NAs por indicador
scores %>%
  select(starts_with("momentum"), starts_with("zscore")) %>%
  summarise(across(everything(), ~mean(is.na(.)))) %>%
  pivot_longer(everything()) %>%
  arrange(desc(value))
```

---

### Q: Como sei quais FIIs têm dados CVM?

**A:**
```r
# Verificar dados CVM
cvm <- readRDS("data/fii_cvm.rds")

# FIIs com dados CVM
fiis_com_cvm <- unique(cvm$ticker)
length(fiis_com_cvm)

# FIIs sem dados CVM
scores <- readRDS("data/fii_scores_enriched.rds")
fiis_sem_cvm <- setdiff(scores$ticker, fiis_com_cvm)

# Ver cobertura
cat(glue("FIIs com CVM: {length(fiis_com_cvm)}\n"))
cat(glue("FIIs sem CVM: {length(fiis_sem_cvm)}\n"))
cat(glue("Cobertura: {round(100*length(fiis_com_cvm)/nrow(scores), 1)}%\n"))
```

**Aumentar cobertura:**
```r
# Adicionar mapping CNPJ manual
mapping <- tibble(
  ticker = c("TICKER11", "OUTRO11"),
  cnpj = c("12345678000190", "98765432000100")
)

saveRDS(mapping, "data/fii_cnpj_mapping.rds")

# Próxima execução tentará usar o mapping
```

---

### Q: Posso exportar scores para Excel/CSV?

**A:** Sim! Pipeline v3.0 exporta automaticamente para CSV:

**Arquivo gerado:**
```r
# CSV é criado automaticamente
"data/fii_scores_enriched.csv"
```

**Exportar manualmente:**
```r
library(writexl)

scores <- readRDS("data/fii_scores_enriched.rds")

# Excel
write_xlsx(scores, "scores.xlsx")

# CSV
write_csv(scores, "scores.csv")

# CSV com encoding brasileiro
write_csv2(scores, "scores.csv")
```

---

## Erros Comuns

### Q: Erro "função não encontrada: run_complete_analysis"

**A:** O arquivo não foi carregado. Execute:

```r
source("R/pipeline/main_complete_pipeline.R")
run_complete_analysis(...)
```

Se o erro persistir:
```r
# Verificar arquivo existe
file.exists("R/pipeline/main_complete_pipeline.R")

# Verificar working directory
getwd()  # Deve ser raiz do projeto

# Se não estiver na raiz
setwd("/caminho/para/fii_manager")
```

---

### Q: Erro "data/portfolio.rds não encontrado"

**A:** Pipeline precisa de dados básicos. Execute primeiro o hybrid pipeline:

```r
source("R/pipeline/hybrid_pipeline.R")
hybrid_pipeline_run()

# Depois execute v3.0
source("R/pipeline/main_complete_pipeline.R")
run_complete_analysis(...)
```

**Ou execute pipeline completo v2.0 primeiro:**
```r
source("R/pipeline/main_portfolio_with_scoring.R")
# Cria todos os arquivos necessários
```

---

### Q: Erro "Can't get Google credentials"

**A:** Autenticação do Google Sheets necessária:

```r
library(googlesheets4)
gs4_auth()  # Abre navegador para autenticar

# Depois rode pipeline normalmente
```

**Para ambientes sem navegador (servidor):**
```r
# Usar service account ou token pre-autenticado
gs4_auth(path = "service-account.json")
```

---

### Q: Warning "CVM validation failed"

**A:** CVM validation warnings são **normais e esperados**. Indicam:

- FIIs sem CNPJ mapping
- Dados inconsistentes entre sources (esperado)
- Campos faltando em alguns meses (normal)

**Pipeline continua executando normalmente.**

**Para suprimir warnings:**
```r
result <- run_complete_analysis(log_level = "ERROR")
```

**Para investigar detalhes:**
```r
# Ver validation details
result$phase_results$clean$cvm
```

---

### Q: Erro "HTTP 429 - Too Many Requests"

**A:** Rate limit atingido. Causas:

1. **StatusInvest rate limiting:**
   - Pipeline híbrido tem rate limiting built-in
   - Se erro persistir, aguardar 5-10 minutos

2. **CVM API rate limiting:**
   - Menos comum
   - Aguardar alguns minutos e tentar novamente

**Solução:**
```r
# Aguardar e tentar novamente
Sys.sleep(300)  # 5 minutos
run_complete_analysis(...)

# Ou pular fontes problemáticas temporariamente
run_complete_analysis(include_cvm = FALSE)
```

---

### Q: Pipeline parou no meio, como continuar?

**A:** Pipeline v3.0 tem checkpoints. Você pode:

**Opção 1: Reexecutar (recomendado)**
```r
# Pipeline detecta dados existentes e pula fases já completas
run_complete_analysis(mode = "incremental")
```

**Opção 2: Executar fases manualmente**
```r
# Se Phase 1-3 completaram, rodar apenas deep indicators
source("R/transform/fii_deep_indicators.R")

scores <- readRDS("data/fii_scores.rds")
cache <- load_deep_indicators_cache()
enriched <- enrich_scores_with_deep_indicators(scores, cache)
saveRDS(enriched, "data/fii_scores_enriched.rds")
```

---

## Troubleshooting Avançado

### Q: Como debugar erros no pipeline?

**A:** **Estratégia de debugging:**

1. **Aumentar log level:**
   ```r
   result <- run_complete_analysis(log_level = "DEBUG")
   ```

2. **Ver logs estruturados:**
   ```r
   # Últimos logs
   log_files <- list.files("data/.logs", full.names = TRUE, pattern = "pipeline")
   latest_log <- log_files[which.max(file.mtime(log_files))]

   # Ler log
   logs <- readLines(latest_log)
   tail(logs, 50)

   # Buscar erros
   grep("ERROR", logs, value = TRUE)
   ```

3. **Verificar resultado por fase:**
   ```r
   # Ver qual fase falhou
   result$summary$failed_phases

   # Detalhes da fase
   result$phase_results$import
   result$errors$import
   ```

4. **Executar fases isoladamente:**
   ```r
   # Testar import
   source("R/pipeline/hybrid_pipeline.R")
   hybrid_result <- hybrid_pipeline_run()

   # Testar CVM
   source("R/import/fii_cvm_data.R")
   cvm_result <- collect_cvm_data()

   # Testar scoring
   source("R/transform/fii_score_pipeline.R")
   scores <- run_scoring_pipeline()
   ```

---

### Q: Como validar integridade dos dados?

**A:**
```r
# Validação automática está embutida no pipeline
result <- run_complete_analysis(...)
result$phase_results$clean  # Ver validation results

# Validação manual
source("R/validators/schema_validator.R")
source("R/validators/cvm_validator.R")

# Validar todos os RDS
validate_all_rds()

# Validar CVM específico
cvm_data <- readRDS("data/fii_cvm.rds")
fiis <- readRDS("data/fiis.rds")
quotations <- readRDS("data/quotations.rds")

validation <- validate_cvm_all(
  cvm_data = cvm_data,
  other_sources = list(fiis = fiis, quotations = quotations)
)

# Ver detalhes
validation$schema
validation$ranges
validation$consistency
validation$completeness
```

---

### Q: Como restaurar backup se pipeline sobrescreveu dados?

**A:**
```r
# Backups automáticos estão em data_backup/
list.files("data_backup", pattern = "fii_scores.*\\.rds")

# Restaurar último backup
backup_files <- list.files("data_backup",
                          pattern = "fii_scores_enriched.*\\.rds",
                          full.names = TRUE)

# Último backup (mais recente)
latest_backup <- backup_files[which.max(file.mtime(backup_files))]

# Restaurar
file.copy(latest_backup, "data/fii_scores_enriched.rds", overwrite = TRUE)

cat(glue("Restored from: {basename(latest_backup)}\n"))
```

---

## Performance Tips

### Q: Configuração ideal para execução diária?

**A:**
```r
# Configuração otimizada diária (~2 min)
run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",       # Apenas portfolio
  include_cvm = FALSE,         # CVM só mensal
  include_deep_indicators = TRUE,  # Vale a pena (~1 min)
  include_analysis = FALSE,    # Análise on-demand
  include_reports = FALSE,     # Relatórios on-demand
  log_level = "INFO"
)
```

---

### Q: Configuração ideal para execução mensal?

**A:**
```r
# Configuração completa mensal (~15 min)
run_complete_analysis(
  mode = "full",
  tickers = "all",             # Todos FIIs
  include_cvm = TRUE,          # Atualizar CVM
  include_deep_indicators = TRUE,
  include_analysis = TRUE,     # Análise portfolio
  include_reports = TRUE,      # Gerar relatórios
  log_level = "INFO"
)
```

---

### Q: Como configurar execução automática (cron)?

**A:**

**Script R para cron:**
```r
#!/usr/bin/env Rscript
# Salvar como: run_daily_pipeline.R

setwd("/caminho/para/fii_manager")
source("R/pipeline/main_complete_pipeline.R")

result <- run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",
  include_cvm = FALSE,
  include_analysis = FALSE,
  log_level = "INFO"
)

# Exit code baseado em sucesso
if (!result$summary$overall_success) {
  quit(status = 1)
}
```

**Crontab (Linux/Mac):**
```bash
# Executar todo dia às 8h
0 8 * * * /usr/bin/Rscript /caminho/para/run_daily_pipeline.R >> /var/log/fii_pipeline.log 2>&1

# Executar todo primeiro dia do mês às 3h (com CVM)
0 3 1 * * /usr/bin/Rscript /caminho/para/run_monthly_pipeline.R >> /var/log/fii_pipeline.log 2>&1
```

**Task Scheduler (Windows):**
- Criar tarefa agendada apontando para `Rscript.exe run_daily_pipeline.R`

---

### Q: Como monitorar execuções agendadas?

**A:**
```r
# Ver metadados de última execução
metadata <- readRDS("data/pipeline_metadata.rds")
metadata$execution_date
metadata$num_fiis
metadata$has_deep_indicators

# Ver logs de erros
log_files <- list.files("data/.logs", full.names = TRUE, pattern = "pipeline")
latest_log <- log_files[which.max(file.mtime(log_files))]

# Contar erros no último log
errors <- system(glue("grep ERROR {latest_log} | wc -l"), intern = TRUE)
cat(glue("Erros no último log: {errors}\n"))

# Ver idade dos dados
scores_age <- difftime(Sys.time(),
                       file.info("data/fii_scores_enriched.rds")$mtime,
                       units = "hours")
cat(glue("Scores têm {round(scores_age, 1)} horas\n"))

# Alertar se dados muito antigos
if (scores_age > 48) {
  warning("Dados desatualizados! Última atualização há mais de 48h")
}
```

---

## Casos de Uso

### Q: Como fazer análise profunda de um FII específico?

**A:**
```r
# Opção 1: Rodar pipeline v3.0 para o FII
result <- run_complete_analysis(
  mode = "incremental",
  tickers = c("HGLG11"),
  include_deep_indicators = TRUE,
  include_analysis = TRUE,
  include_reports = TRUE
)

# Análise estará em:
# - data/fii_analyses_YYYYMMDD.rds
# - reports/YYYY-MM-DD/HGLG11_analysis.md

# Opção 2: Análise on-demand (mais rápido)
source("R/analysis/fii_individual_analysis.R")

analysis <- analyze_fii_deep("HGLG11")
print_fii_analysis(analysis)

# 7 seções:
# 1. Perfil
# 2. Qualidade
# 3. Renda
# 4. Valuation
# 5. Risco
# 6. Cenários
# 7. Alertas
```

---

### Q: Como comparar meu portfolio com o mercado?

**A:**
```r
source("R/analysis/fii_analysis.R")

scores <- readRDS("data/fii_scores_enriched.rds")
portfolio <- readRDS("data/portfolio.rds")

# Scores do portfolio
portfolio_scores <- scores %>%
  filter(ticker %in% portfolio$ticker)

# Comparar com mercado
comparison <- tibble(
  metric = c("Score médio", "DY médio", "P/VP médio"),
  portfolio = c(
    mean(portfolio_scores$total_score, na.rm = TRUE),
    mean(portfolio_scores$dy_12m, na.rm = TRUE),
    mean(portfolio_scores$pvp, na.rm = TRUE)
  ),
  mercado = c(
    mean(scores$total_score, na.rm = TRUE),
    mean(scores$dy_12m, na.rm = TRUE),
    mean(scores$pvp, na.rm = TRUE)
  )
)

comparison %>%
  mutate(diff = portfolio - mercado) %>%
  print()
```

---

### Q: Como encontrar oportunidades de investimento?

**A:**
```r
source("R/analysis/fii_opportunities.R")

scores <- readRDS("data/fii_scores_enriched.rds")

# Busca avançada
opportunities <- identify_opportunities(
  scores,
  user_profile = list(
    risk_tolerance = "moderate",  # low, moderate, high
    preferred_segments = c("Logística", "Lajes Corporativas"),
    min_liquidity = 1000000,
    investment_horizon = "long"  # short, medium, long
  ),
  min_score = 65,
  min_dy = 0.10,
  max_pvp = 1.1
)

# Ver top 10
opportunities$top_opportunities %>%
  head(10) %>%
  select(ticker, total_score, dy_12m, pvp, recommendation, opportunity_type)
```

---

## Recursos Adicionais

- **Tutorial completo:** [`TUTORIAL_COMPLETE_ANALYSIS.md`](TUTORIAL_COMPLETE_ANALYSIS.md)
- **Guia de migração:** [`MIGRATION_V2_TO_V3.md`](MIGRATION_V2_TO_V3.md)
- **Documentação técnica:** [`pipeline_v3_usage.md`](pipeline_v3_usage.md)
- **Deep indicators:** [`deep_indicators_implementation.md`](deep_indicators_implementation.md)

---

**Não encontrou sua pergunta?**

Verifique os logs em `data/.logs/` para informações detalhadas sobre execução e erros.

---

**Versão:** 3.0.0
**Data:** 2026-03-21
**Status:** ✅ Completo
