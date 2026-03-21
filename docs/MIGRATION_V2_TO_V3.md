# Guia de Migração: v2.0 → v3.0

Este guia detalha como migrar seus workflows da versão 2.0 para a 3.0 do FII Manager Pipeline.

**Boa notícia:** v3.0 é **100% retrocompatível** com v2.0. Você pode adotar as novas features incrementalmente.

---

## 📋 Índice

1. [Resumo das Mudanças](#resumo-das-mudanças)
2. [Breaking Changes](#breaking-changes)
3. [Novos Requisitos](#novos-requisitos)
4. [Checklist de Migração](#checklist-de-migração)
5. [Atualizando Workflows](#atualizando-workflows)
6. [Troubleshooting](#troubleshooting)

---

## Resumo das Mudanças

### O que há de novo na v3.0

**Arquitetura:**
- 8 camadas (antes: 3 camadas)
- 7 fases orquestradas (antes: 2 fases)
- Pipeline completo unificado (antes: pipelines separados)

**Dados:**
- Dados CVM oficiais (fundamentalista)
- 15 novos indicadores deep
- Validação em 4 níveis

**Análise:**
- Análise individual profunda (7 seções)
- Busca avançada de oportunidades
- Relatórios markdown automáticos

**Performance:**
- Mesma velocidade para operações básicas
- Novas funcionalidades adicionam ~1-10min (opcional)

### O que permanece igual

✅ **Todos os workflows v2.0 continuam funcionando:**
- `main_portfolio_with_scoring.R` - Funciona normalmente
- `fii_analysis.R`, `fii_comparison.R` - Sem mudanças
- Estrutura de dados (`fii_scores.rds`) - Mesmo formato
- Funções de análise - Mesma API

✅ **Arquivos de dados:**
- Todos os RDS v2.0 continuam válidos
- Novos arquivos são adicionados (não substituem)

---

## Breaking Changes

**Nenhum breaking change!**

v3.0 é totalmente retrocompatível. Todas as funções e workflows v2.0 continuam funcionando.

---

## Novos Requisitos

### Pacotes R

**Nenhuma nova dependência de pacote.**

v3.0 usa o mesmo stack de pacotes que v2.0:
- tidyverse
- lubridate
- glue
- yaml
- googlesheets4

### Arquivos de Dados

**Opcional - CVM Data:**

Se quiser usar indicadores deep que dependem de dados CVM, você precisa:

1. Conexão com internet (para download inicial)
2. Mapping CNPJ opcional: `data/fii_cnpj_mapping.rds`
   - Pipeline funciona sem, mas alguns FIIs podem não ter dados CVM

**Estrutura de diretórios (criados automaticamente):**

```
data_backup/         # Backups automáticos (novo em v3.0)
reports/             # Relatórios markdown (novo em v3.0)
  └── YYYY-MM-DD/
```

### Espaço em Disco

**Adicional estimado:**
- `fii_cvm.rds`: ~1-5 MB (depende do número de meses)
- `fii_scores_enriched.rds`: ~500 KB - 2 MB
- `fii_analyses_*.rds`: ~1-10 MB (se usar análise individual)
- Backups: ~500 KB por backup (criados automaticamente)
- Reports: ~10-50 KB por FII (se gerar relatórios)

**Total:** ~10-50 MB adicional

---

## Checklist de Migração

### ✅ Passo 1: Backup (Recomendado)

Faça backup da sua pasta `data/` antes de migrar:

```bash
# No terminal
cp -r data/ data_backup_pre_v3_$(date +%Y%m%d)/
```

Ou em R:

```r
# Backup manual
backup_dir <- glue("data_backup_pre_v3_{format(Sys.Date(), '%Y%m%d')}")
dir.create(backup_dir, showWarnings = FALSE)

# Copiar arquivos
data_files <- list.files("data", pattern = "\\.rds$", full.names = TRUE)
file.copy(data_files, backup_dir)
```

### ✅ Passo 2: Atualizar Código

**Opção A: Git Pull (se usando git)**

```bash
git pull origin master
```

**Opção B: Download Manual**

1. Baixar arquivos novos:
   - `R/pipeline/main_complete_pipeline.R`
   - `R/transform/fii_deep_indicators.R`
   - `R/import/fii_cvm_data.R`
   - `R/validators/cvm_validator.R`
   - `R/analysis/fii_individual_analysis.R`
   - `R/analysis/fii_opportunities.R`

2. Baixar documentação:
   - `docs/pipeline_v3_usage.md`
   - `docs/MIGRATION_V2_TO_V3.md` (este arquivo)
   - `docs/FAQ_PIPELINE_V3.md`
   - `docs/TUTORIAL_COMPLETE_ANALYSIS.md`

3. Atualizar:
   - `README.md`
   - `CHANGELOG.md` (novo)

### ✅ Passo 3: Verificar Instalação

Execute verificação básica:

```r
# Verificar que arquivos existem
required_files <- c(
  "R/pipeline/main_complete_pipeline.R",
  "R/transform/fii_deep_indicators.R",
  "R/import/fii_cvm_data.R",
  "R/validators/cvm_validator.R",
  "R/analysis/fii_individual_analysis.R"
)

all(file.exists(required_files))
# Deve retornar TRUE
```

### ✅ Passo 4: Teste Básico

Execute pipeline v3.0 em modo incremental (rápido):

```r
source("R/pipeline/main_complete_pipeline.R")

# Teste rápido: portfolio, sem CVM, sem análise
result <- run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",
  include_cvm = FALSE,
  include_deep_indicators = TRUE,
  include_analysis = FALSE,
  include_reports = FALSE
)

# Verificar sucesso
result$summary$overall_success
# Deve retornar TRUE
```

### ✅ Passo 5: Teste Completo (Opcional)

Execute pipeline completo com todas as features:

```r
# Teste completo: todos FIIs, com CVM, com análise
result <- run_complete_analysis(
  mode = "full",
  tickers = "all",
  include_cvm = TRUE,
  include_deep_indicators = TRUE,
  include_analysis = TRUE,
  include_reports = TRUE
)

# Verificar arquivos gerados
list.files("data", pattern = "enriched|cvm|analyses")
# Deve listar: fii_cvm.rds, fii_scores_enriched.rds, fii_analyses_*.rds

list.files("reports", recursive = TRUE)
# Deve listar relatórios markdown
```

### ✅ Passo 6: Validar Dados

Execute validações para garantir integridade:

```r
# Carregar scores enriquecidos
scores <- readRDS("data/fii_scores_enriched.rds")

# Verificar estrutura
nrow(scores)  # Deve ter FIIs
ncol(scores)  # Deve ter mais colunas que v2.0

# Verificar deep indicators
deep_cols <- c("alavancagem", "momentum_3m", "zscore_dy_segmento")
sum(deep_cols %in% names(scores))  # Deve ser 3

# Verificar compatibilidade com v2.0
basic_scores <- readRDS("data/fii_scores.rds")
all(c("ticker", "total_score", "recommendation") %in% names(basic_scores))
# Deve ser TRUE
```

---

## Atualizando Workflows

### Workflow 1: Pipeline Diário

**Antes (v2.0):**
```r
source("R/pipeline/main_portfolio_with_scoring.R")
```

**Depois (v3.0) - Opção 1: Manter v2.0 (funciona)**
```r
source("R/pipeline/main_portfolio_with_scoring.R")
# Continua funcionando normalmente
```

**Depois (v3.0) - Opção 2: Migrar para v3.0 (recomendado)**
```r
source("R/pipeline/main_complete_pipeline.R")

result <- run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",
  include_cvm = FALSE,        # Pular CVM no diário
  include_deep_indicators = TRUE,  # Deep indicators são rápidos
  include_analysis = FALSE,   # Análise individual é lenta
  include_reports = FALSE
)
```

**Benefícios da migração:**
- Validação automática em 4 níveis
- Deep indicators adicionados (~1 min)
- Auto-backup antes de sobrescrever
- Metadata tracking

---

### Workflow 2: Análise de Portfolio

**Antes (v2.0):**
```r
source("R/analysis/fii_analysis.R")

scores <- readRDS("data/fii_scores.rds")
portfolio_summary <- analyze_portfolio(scores)
```

**Depois (v3.0) - Sem mudanças necessárias:**
```r
source("R/analysis/fii_analysis.R")

# Pode usar scores básicos (v2.0)
scores <- readRDS("data/fii_scores.rds")
portfolio_summary <- analyze_portfolio(scores)

# OU usar scores enriquecidos (v3.0) - mesma API
scores <- readRDS("data/fii_scores_enriched.rds")
portfolio_summary <- analyze_portfolio(scores)
# Funciona igual, mas com mais indicadores disponíveis
```

---

### Workflow 3: Buscar Oportunidades

**Antes (v2.0):**
```r
source("R/analysis/fii_analysis.R")

scores <- readRDS("data/fii_scores.rds")
opportunities <- find_opportunities(
  scores,
  min_score = 70,
  min_dy = 0.10
)
```

**Depois (v3.0) - Opção 1: Manter v2.0 (funciona)**
```r
source("R/analysis/fii_analysis.R")

scores <- readRDS("data/fii_scores.rds")
opportunities <- find_opportunities(
  scores,
  min_score = 70,
  min_dy = 0.10
)
# Continua funcionando
```

**Depois (v3.0) - Opção 2: Usar nova busca avançada (recomendado)**
```r
source("R/analysis/fii_opportunities.R")

scores <- readRDS("data/fii_scores_enriched.rds")
opportunities <- identify_opportunities(
  scores,
  user_profile = list(
    risk_tolerance = "moderate",
    preferred_segments = c("Logística", "Lajes Corporativas"),
    min_liquidity = 1000000
  ),
  min_score = 70
)

# Retorna ranking avançado com classificação de tipo
# (value, growth, income, hybrid)
```

**Benefícios da nova busca:**
- Filtros multi-critério mais sofisticados
- Ranking avançado considerando perfil
- Classificação de oportunidades (value/growth/income)
- Usa deep indicators para melhor avaliação

---

### Workflow 4: Análise Individual de FII

**Antes (v2.0):**
```r
# Análise manual ou via scripts específicos
source("R/analysis/fii_comparison.R")

scores <- readRDS("data/fii_scores.rds")
peers <- compare_with_peers("HGLG11", scores)
```

**Depois (v3.0) - Nova funcionalidade:**
```r
source("R/analysis/fii_individual_analysis.R")

# Análise profunda com 7 seções
analysis <- analyze_fii_deep("HGLG11")

# Ver análise formatada
print_fii_analysis(analysis)

# Seções disponíveis:
# 1. Perfil
# 2. Qualidade (com deep indicators)
# 3. Renda
# 4. Valuation
# 5. Risco
# 6. Cenários
# 7. Alertas

# Ainda pode usar peer comparison do v2.0
source("R/analysis/fii_comparison.R")
peers <- compare_with_peers("HGLG11", scores)
```

---

### Workflow 5: Pipeline Mensal Completo

**Antes (v2.0):**
```r
source("R/pipeline/main_portfolio_with_scoring.R")
# ~4 minutos

# Análises manuais depois
source("R/analysis/fii_analysis.R")
opportunities <- find_opportunities(scores)
```

**Depois (v3.0) - Completo em uma chamada:**
```r
source("R/pipeline/main_complete_pipeline.R")

result <- run_complete_analysis(
  mode = "full",
  tickers = "all",
  include_cvm = TRUE,              # Coleta CVM (mensal)
  include_deep_indicators = TRUE,
  include_analysis = TRUE,         # Análise individual
  include_reports = TRUE           # Gera relatórios markdown
)

# ~12-15 minutos (depende do número de FIIs)

# Outputs:
# - data/fii_cvm.rds
# - data/fii_scores_enriched.rds
# - data/fii_analyses_YYYYMMDD.rds
# - reports/YYYY-MM-DD/*.md
```

---

## Estratégia de Adoção Gradual

Recomendamos adotar v3.0 gradualmente:

### Semana 1: Familiarização
```r
# Continue usando v2.0 para produção
source("R/pipeline/main_portfolio_with_scoring.R")

# Teste v3.0 em paralelo (não sobrescreve)
result <- run_complete_analysis(
  mode = "incremental",
  include_cvm = FALSE,
  include_analysis = FALSE
)

# Compare outputs
scores_v2 <- readRDS("data/fii_scores.rds")
scores_v3 <- readRDS("data/fii_scores_enriched.rds")

# Scores básicos devem ser iguais
all.equal(
  scores_v2[, c("ticker", "total_score")],
  scores_v3[, c("ticker", "total_score")]
)
```

### Semana 2: Deep Indicators
```r
# Adote deep indicators em produção
source("R/pipeline/main_complete_pipeline.R")

result <- run_complete_analysis(
  mode = "incremental",
  include_cvm = TRUE,   # Primeira vez com CVM
  include_deep_indicators = TRUE
)

# Explore novos indicadores
scores <- readRDS("data/fii_scores_enriched.rds")

# Visualize deep indicators
library(ggplot2)

scores %>%
  filter(!is.na(momentum_12m)) %>%
  ggplot(aes(x = momentum_12m, y = total_score, color = segmento)) +
  geom_point() +
  labs(title = "Score vs Momentum 12m")
```

### Semana 3: Análise Individual
```r
# Adicione análise individual para FIIs chave
source("R/analysis/fii_individual_analysis.R")

# Analise top holdings do portfolio
portfolio <- readRDS("data/portfolio.rds")
top_holdings <- portfolio %>%
  arrange(desc(value)) %>%
  head(5) %>%
  pull(ticker)

analyses <- map(top_holdings, analyze_fii_deep)
names(analyses) <- top_holdings

# Ver análise
print_fii_analysis(analyses$HGLG11)
```

### Semana 4: Pipeline Completo
```r
# Substitua workflow v2.0 por v3.0
source("R/pipeline/main_complete_pipeline.R")

# Diário
run_complete_analysis(
  mode = "incremental",
  include_cvm = FALSE
)

# Mensal
run_complete_analysis(
  mode = "full",
  include_cvm = TRUE,
  include_analysis = TRUE,
  include_reports = TRUE
)
```

---

## Troubleshooting

### Erro: "função não encontrada"

**Problema:** Função v3.0 não está disponível.

**Solução:**
```r
# Verificar que arquivo foi carregado
source("R/pipeline/main_complete_pipeline.R")

# Se erro persiste, verificar arquivo existe
file.exists("R/pipeline/main_complete_pipeline.R")

# Verificar dependencies
source("R/transform/fii_deep_indicators.R")
source("R/import/fii_cvm_data.R")
```

---

### Scores v3.0 diferentes de v2.0

**Problema:** `total_score` difere entre `fii_scores.rds` e `fii_scores_enriched.rds`.

**Explicação:** Isso é **esperado** se você rodou v3.0 com dados mais recentes que v2.0.

**Solução:**
```r
# Verificar timestamps
metadata_v2 <- file.info("data/fii_scores.rds")$mtime
metadata_v3 <- file.info("data/fii_scores_enriched.rds")$mtime

metadata_v3 - metadata_v2
# Se diferença > 1 hora, scores foram calculados com dados diferentes

# Para comparar apple-to-apple, delete scores e rode v3.0 do zero
file.remove("data/fii_scores.rds")
file.remove("data/fii_scores_enriched.rds")

source("R/pipeline/main_complete_pipeline.R")
run_complete_analysis(mode = "full")
```

---

### Deep indicators com muitos NAs

**Problema:** Muitos `NA` em colunas deep indicators.

**Causa:** Deep indicators precisam de:
1. Dados CVM (para indicadores de qualidade)
2. Histórico de scores (para momentum)
3. Dados do segmento (para z-scores)

**Solução:**
```r
# 1. Coletar dados CVM
result <- run_complete_analysis(
  mode = "full",
  include_cvm = TRUE
)

# 2. Verificar dados CVM
cvm <- readRDS("data/fii_cvm.rds")
nrow(cvm)  # Deve ter linhas

# 3. Construir histórico (executar v3.0 por 2-3 dias)
# Momentum precisa de histórico de scores

# 4. Verificar melhorias
scores <- readRDS("data/fii_scores_enriched.rds")

# % de NAs por indicador
scores %>%
  select(starts_with("momentum"), starts_with("zscore")) %>%
  summarise(across(everything(), ~mean(is.na(.))))
```

---

### CVM validation warnings

**Problema:** Warnings sobre validação CVM no log.

**Explicação:** Normal. CVM validation pode detectar:
- FIIs sem CNPJ mapping
- Dados inconsistentes entre sources
- Campos faltando em alguns meses

**Solução:** Warnings são **informativos**, não erros. Pipeline continua.

Para adicionar CNPJ mapping:
```r
# Criar mapping manual
mapping <- tibble(
  ticker = c("HGLG11", "KNRI11"),
  cnpj = c("12345678000199", "98765432000188")
)

# Salvar
saveRDS(mapping, "data/fii_cnpj_mapping.rds")

# Próxima execução usará mapping
```

---

### Pipeline v3.0 mais lento que v2.0

**Problema:** v3.0 demora mais que v2.0.

**Explicação:** v3.0 adiciona:
- Validação (4 níveis): +30s
- Deep indicators: +1 min
- CVM collection (se habilitado): +5-8 min

**Solução:**

Para execução diária rápida:
```r
run_complete_analysis(
  mode = "incremental",
  include_cvm = FALSE,        # Pular CVM (fazer mensal)
  include_analysis = FALSE,   # Pular análise individual
  include_reports = FALSE
)
# ~2-3 min (similar a v2.0)
```

Para manter velocidade v2.0:
```r
# Continue usando v2.0
source("R/pipeline/main_portfolio_with_scoring.R")
```

---

## Rollback para v2.0

Se precisar voltar para v2.0:

```r
# v2.0 workflows continuam funcionando
source("R/pipeline/main_portfolio_with_scoring.R")

# Arquivos v2.0 não foram modificados:
# - data/fii_scores.rds (v2.0 format)
# - data/fii_scores_history.rds

# v3.0 cria arquivos novos (não substitui):
# - data/fii_scores_enriched.rds
# - data/fii_cvm.rds
# - data/fii_analyses_*.rds
```

**Nenhuma ação necessária para rollback.**

---

## Suporte

Para issues durante migração:

1. **Verificar logs:** `data/.logs/pipeline_*.log`
2. **Consultar FAQ:** `docs/FAQ_PIPELINE_V3.md`
3. **Tutorial completo:** `docs/TUTORIAL_COMPLETE_ANALYSIS.md`
4. **Documentação técnica:** `docs/pipeline_v3_usage.md`

---

## Próximos Passos

Após migração bem-sucedida:

1. **Explore deep indicators:**
   ```r
   scores <- readRDS("data/fii_scores_enriched.rds")
   names(scores)  # Ver novos indicadores
   ```

2. **Teste análise individual:**
   ```r
   analysis <- analyze_fii_deep("HGLG11")
   print_fii_analysis(analysis)
   ```

3. **Configure pipeline mensal:**
   - Diário: `mode = "incremental"`, `include_cvm = FALSE`
   - Mensal: `mode = "full"`, `include_cvm = TRUE`

4. **Explore relatórios markdown:**
   ```r
   list.files("reports", recursive = TRUE, pattern = "\\.md$")
   ```

---

**Versão:** 3.0.0
**Data:** 2026-03-21
**Status:** ✅ Completo
