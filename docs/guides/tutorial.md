# Tutorial Completo - Pipeline v3.0

Tutorial passo-a-passo para primeira execução do Pipeline v3.0, desde instalação até análise completa de FIIs.

---

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Setup Inicial](#setup-inicial)
3. [Primeira Execução](#primeira-execução)
4. [Explorando Resultados](#explorando-resultados)
5. [Análises Avançadas](#análises-avançadas)
6. [Uso Recorrente](#uso-recorrente)

---

## Pré-requisitos

### Software Necessário

✅ **R (>= 4.0.0)**
```bash
# Verificar versão
R --version
```

✅ **RStudio (recomendado)**
- Download: https://www.rstudio.com/products/rstudio/download/

✅ **Git (para clonar repositório)**
```bash
git --version
```

### Pacotes R Necessários

```r
# Instalar pacotes (primeira vez)
install.packages(c(
  "tidyverse",    # Data manipulation e visualização
  "lubridate",    # Date handling
  "glue",         # String interpolation
  "yaml",         # Config files
  "googlesheets4",# Google Sheets integration
  "httr2",        # HTTP client
  "rvest",        # Web scraping
  "jsonlite",     # JSON parsing
  "plotly"        # Interactive plots
))
```

**Tempo estimado de instalação:** 5-10 minutos

---

## Setup Inicial

### Passo 1: Clonar Repositório

```bash
# Clonar projeto
git clone <URL_DO_REPOSITORIO> fii_manager
cd fii_manager
```

Ou baixar ZIP e extrair.

---

### Passo 2: Configurar Working Directory

No RStudio:
1. Menu: `File > Open Project...`
2. Selecionar `fii_manager.Rproj`
3. RStudio configura working directory automaticamente

Ou no R:
```r
setwd("/caminho/para/fii_manager")
getwd()  # Verificar
```

---

### Passo 3: Autenticar Google Sheets

O pipeline precisa acessar seu portfolio no Google Sheets.

**3.1. Preparar Google Sheet**

1. Criar Google Sheet com colunas:
   - `date` (data de compra)
   - `ticker` (código do FII, ex: "HGLG11")
   - `volume` (quantidade de cotas)
   - `price` (preço de compra)
   - `taxes` (taxas de corretagem)
   - `value` (valor total investido)
   - `portfolio` (nome do portfolio)

2. Copiar ID do sheet da URL:
   ```
   https://docs.google.com/spreadsheets/d/1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU/edit
                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                          Este é o sheet ID
   ```

3. Atualizar ID em `R/import/portfolioGoogleSheets.R`:
   ```r
   # Linha ~20
   SHEET_KEY <- "SEU_SHEET_ID_AQUI"
   ```

**3.2. Autenticar**

```r
library(googlesheets4)

# Autenticar (abre navegador)
gs4_auth()

# Testar acesso
gs4_get("SEU_SHEET_ID")
# Deve retornar informações do sheet
```

**Primeiro uso:** Navegador abrirá pedindo permissão. Autorizar.

**Reuso:** Token salvo em `~/.R/gargle/`, não precisa reautenticar.

---

### Passo 4: Estrutura de Diretórios

```r
# Criar diretórios necessários (automático, mas pode criar manualmente)
dirs <- c(
  "data",
  "data/.cache",
  "data/.logs",
  "data_backup",
  "reports",
  "config"
)

for (d in dirs) {
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
}

cat("✓ Diretórios criados\n")
```

---

## Primeira Execução

### Execução Básica (Recomendada para Início)

Vamos executar pipeline básico primeiro, sem opções avançadas.

**Passo 1: Carregar Pipeline**

```r
source("R/pipeline/main_complete_pipeline.R")
```

Se erros de "função não encontrada", verificar working directory está correto.

---

**Passo 2: Executar Pipeline Básico**

```r
cat("\n🚀 Iniciando primeira execução do Pipeline v3.0...\n\n")

result <- run_complete_analysis(
  mode = "full",                    # Full refresh (primeira vez)
  tickers = "portfolio",            # Apenas portfolio (mais rápido)
  include_cvm = FALSE,              # Pular CVM (por enquanto)
  include_deep_indicators = TRUE,   # Habilitar deep indicators
  include_analysis = FALSE,         # Pular análise individual (por enquanto)
  include_reports = FALSE,          # Pular relatórios (por enquanto)
  log_level = "INFO"
)

cat("\n✅ Primeira execução completa!\n")
```

**Tempo estimado:** 3-5 minutos

**O que acontece:**
1. **IMPORT** - Coleta dados do Google Sheets, StatusInvest, Yahoo, Lupa (~2 min)
2. **CLEAN** - Valida dados coletados (~5 seg)
3. **TRANSFORM** - Calcula scores básicos (11 indicadores) (~30 seg)
4. **DEEP** - Adiciona deep indicators (~30 seg)
5. **PERSIST** - Salva resultados e backups (~5 seg)

---

**Passo 3: Verificar Sucesso**

```r
# Status geral
result$summary$overall_success
# TRUE = sucesso!

# Ver fases completadas
result$summary$completed_phases
# [1] "import" "clean" "transform" "deep" "persist"

# Ver arquivos gerados
list.files("data", pattern = "\\.rds$")
# Deve listar: portfolio.rds, quotations.rds, income.rds, fiis.rds,
#              fii_scores.rds, fii_scores_enriched.rds, ...
```

**Se `overall_success = TRUE`:** 🎉 Parabéns! Pipeline funcionou!

**Se `overall_success = FALSE`:**
```r
# Ver erros
result$errors

# Ver logs
log_files <- list.files("data/.logs", full.names = TRUE, pattern = "pipeline")
latest_log <- log_files[which.max(file.mtime(log_files))]
tail(readLines(latest_log), 20)
```

Consultar [FAQ](FAQ_PIPELINE_V3.md) para troubleshooting.

---

## Explorando Resultados

### Passo 1: Carregar Scores

```r
library(tidyverse)

# Carregar scores enriquecidos
scores <- readRDS("data/fii_scores_enriched.rds")

# Ver estrutura
dim(scores)
# [n FIIs] x [indicadores]

names(scores) %>% head(20)
# Ver primeiras 20 colunas
```

---

### Passo 2: Visualizar Scores

```r
# Top 10 FIIs por score
scores %>%
  arrange(desc(total_score)) %>%
  select(ticker, total_score, recommendation, dy_12m, pvp) %>%
  head(10)

# Distribuição de scores
summary(scores$total_score)

# Visualizar
library(ggplot2)

ggplot(scores, aes(x = total_score)) +
  geom_histogram(bins = 30, fill = "steelblue", alpha = 0.7) +
  geom_vline(xintercept = median(scores$total_score, na.rm = TRUE),
             color = "red", linetype = "dashed") +
  labs(
    title = "Distribuição de Scores - FIIs",
    x = "Total Score",
    y = "Frequência"
  ) +
  theme_minimal()
```

---

### Passo 3: Filtrar por Recomendação

```r
# Contar por recomendação
scores %>%
  count(recommendation) %>%
  arrange(desc(n))

# FIIs para COMPRAR
comprar <- scores %>%
  filter(recommendation == "COMPRAR") %>%
  arrange(desc(total_score)) %>%
  select(ticker, total_score, dy_12m, pvp, segmento)

print(comprar)
```

---

### Passo 4: Analisar Segmentos

```r
# Scores por segmento
scores %>%
  group_by(segmento) %>%
  summarise(
    n_fiis = n(),
    score_medio = mean(total_score, na.rm = TRUE),
    dy_medio = mean(dy_12m, na.rm = TRUE),
    pvp_medio = mean(pvp, na.rm = TRUE)
  ) %>%
  arrange(desc(score_medio))

# Visualizar
ggplot(scores, aes(x = segmento, y = total_score, fill = segmento)) +
  geom_boxplot() +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(
    title = "Distribuição de Scores por Segmento",
    x = "Segmento",
    y = "Total Score"
  )
```

---

### Passo 5: Explorar Deep Indicators

```r
# Ver deep indicators disponíveis
deep_cols <- names(scores) %>%
  str_subset("alavancagem|momentum|zscore|percentil|concentracao")

print(deep_cols)

# Análise de momentum
scores %>%
  filter(!is.na(momentum_12m)) %>%
  arrange(desc(momentum_12m)) %>%
  select(ticker, total_score, momentum_12m, dy_12m) %>%
  head(10)

# Visualizar momentum vs score
scores %>%
  filter(!is.na(momentum_12m)) %>%
  ggplot(aes(x = momentum_12m, y = total_score)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", color = "red") +
  labs(
    title = "Momentum 12m vs Score",
    x = "Momentum 12m",
    y = "Total Score"
  ) +
  theme_minimal()
```

---

## Análises Avançadas

### Análise 1: Análise Individual de FII

Agora vamos fazer análise profunda de um FII específico.

```r
source("R/analysis/fii_individual_analysis.R")

# Escolher FII do portfolio
portfolio <- readRDS("data/portfolio.rds")
my_fii <- portfolio$ticker[1]  # Primeiro FII do portfolio

cat(glue("\n📊 Analisando {my_fii}...\n\n"))

# Análise profunda (7 seções)
analysis <- analyze_fii_deep(my_fii)

# Ver análise formatada no console
print_fii_analysis(analysis)

# Explorar seções individualmente
analysis$perfil       # Perfil básico
analysis$qualidade    # Análise de qualidade
analysis$renda        # Análise de renda
analysis$valuation    # Análise de valuation
analysis$risco        # Análise de risco
analysis$cenarios     # Cenários
analysis$alertas      # Pontos de atenção
```

**Output esperado:**

```
══════════════════════════════════════════════════════════════
  ANÁLISE PROFUNDA: HGLG11
══════════════════════════════════════════════════════════════

1️⃣ PERFIL DO FII
────────────────────────────────────────────────────────────
Segmento:             Logística
Patrimônio Líquido:   R$ 1.234.567.890
Número de Cotistas:   123.456
Score Total:          75.3 (COMPRAR)

2️⃣ ANÁLISE DE QUALIDADE
────────────────────────────────────────────────────────────
Score Bloco A:        80.2 (ALTO)
...

[7 seções completas]
```

---

### Análise 2: Busca de Oportunidades

```r
source("R/analysis/fii_opportunities.R")

# Busca avançada com seu perfil
opportunities <- identify_opportunities(
  scores,
  user_profile = list(
    risk_tolerance = "moderate",      # low, moderate, high
    preferred_segments = c("Logística", "Lajes Corporativas"),
    min_liquidity = 1000000,          # R$ 1 milhão/dia
    investment_horizon = "long"       # short, medium, long
  ),
  min_score = 65,
  min_dy = 0.10,      # 10% DY mínimo
  max_pvp = 1.1       # P/VP máximo 1.1
)

# Top 10 oportunidades
opportunities$top_opportunities %>%
  head(10) %>%
  select(ticker, total_score, dy_12m, pvp, opportunity_type, score_justification)

# Oportunidades de valor (P/VP baixo)
opportunities$top_opportunities %>%
  filter(opportunity_type == "value") %>%
  head(5)

# Oportunidades de crescimento
opportunities$top_opportunities %>%
  filter(opportunity_type == "growth") %>%
  head(5)
```

---

### Análise 3: Comparação de Portfolio vs Mercado

```r
# Carregar portfolio
portfolio <- readRDS("data/portfolio.rds")

# Scores do portfolio
portfolio_scores <- scores %>%
  filter(ticker %in% portfolio$ticker)

# Estatísticas comparativas
comparison <- tibble(
  metric = c(
    "Número de FIIs",
    "Score médio",
    "Score mediano",
    "DY 12m médio",
    "P/VP médio",
    "% COMPRAR",
    "% EVITAR"
  ),
  portfolio = c(
    nrow(portfolio_scores),
    round(mean(portfolio_scores$total_score, na.rm = TRUE), 1),
    round(median(portfolio_scores$total_score, na.rm = TRUE), 1),
    round(mean(portfolio_scores$dy_12m, na.rm = TRUE), 4),
    round(mean(portfolio_scores$pvp, na.rm = TRUE), 2),
    round(100 * mean(portfolio_scores$recommendation == "COMPRAR", na.rm = TRUE), 1),
    round(100 * mean(portfolio_scores$recommendation == "EVITAR", na.rm = TRUE), 1)
  ),
  mercado = c(
    nrow(scores),
    round(mean(scores$total_score, na.rm = TRUE), 1),
    round(median(scores$total_score, na.rm = TRUE), 1),
    round(mean(scores$dy_12m, na.rm = TRUE), 4),
    round(mean(scores$pvp, na.rm = TRUE), 2),
    round(100 * mean(scores$recommendation == "COMPRAR", na.rm = TRUE), 1),
    round(100 * mean(scores$recommendation == "EVITAR", na.rm = TRUE), 1)
  )
)

comparison %>%
  mutate(
    diferenca = portfolio - mercado,
    status = case_when(
      diferenca > 0 ~ "✓ Melhor",
      diferenca < 0 ~ "✗ Pior",
      TRUE ~ "= Igual"
    )
  ) %>%
  print()
```

---

## Uso Recorrente

### Execução Diária (Rápida)

```r
# Configuração otimizada para uso diário
source("R/pipeline/main_complete_pipeline.R")

result <- run_complete_analysis(
  mode = "incremental",
  tickers = "portfolio",
  include_cvm = FALSE,
  include_deep_indicators = TRUE,
  include_analysis = FALSE,
  include_reports = FALSE,
  log_level = "INFO"
)

# ~2-3 minutos
```

**Quando executar:** Todo dia útil antes da abertura do mercado ou ao final do dia.

---

### Execução Mensal (Completa)

```r
# Configuração completa para análise mensal
source("R/pipeline/main_complete_pipeline.R")

result <- run_complete_analysis(
  mode = "full",
  tickers = "all",
  include_cvm = TRUE,          # Atualizar dados CVM
  include_deep_indicators = TRUE,
  include_analysis = TRUE,     # Análise de todos FIIs do portfolio
  include_reports = TRUE,      # Gerar relatórios markdown
  log_level = "INFO"
)

# ~15-20 minutos

# Ver relatórios gerados
list.files("reports", recursive = TRUE, pattern = "\\.md$")
```

**Quando executar:** Primeiro dia útil do mês.

---

### Análise On-Demand

Para análises pontuais sem rodar pipeline completo:

```r
# Carregar scores mais recentes
scores <- readRDS("data/fii_scores_enriched.rds")

# Análise individual
source("R/analysis/fii_individual_analysis.R")
analysis <- analyze_fii_deep("TICKER11")
print_fii_analysis(analysis)

# Buscar oportunidades
source("R/analysis/fii_opportunities.R")
opportunities <- identify_opportunities(scores, min_score = 70)

# Comparar FII com pares
source("R/analysis/fii_comparison.R")
peers <- compare_with_peers("TICKER11", scores)
```

---

## Troubleshooting Rápido

### Pipeline falhou

```r
# Ver o que falhou
result$summary$failed_phases

# Ver detalhes do erro
result$errors

# Ver logs
log_files <- list.files("data/.logs", full.names = TRUE)
latest <- log_files[which.max(file.mtime(log_files))]
tail(readLines(latest), 50)
```

### Deep indicators com muitos NAs

**Normal na primeira execução.** Deep indicators precisam de:
- Dados CVM (rodar com `include_cvm = TRUE`)
- Histórico (executar por alguns dias para construir histórico de momentum)

### Portfolio vazio

Verificar:
```r
portfolio <- readRDS("data/portfolio.rds")
nrow(portfolio)  # Deve ter linhas

# Se vazio, verificar Google Sheet
library(googlesheets4)
gs4_get("SEU_SHEET_ID")
```

---

## Próximos Passos

Após dominar o básico:

1. **Explorar dashboards RMarkdown:**
   ```r
   rmarkdown::render("R/dashboard/portfolio.Rmd")
   ```

2. **Automatizar execuções diárias** (ver [FAQ](FAQ_PIPELINE_V3.md#q-como-configurar-execução-automática-cron))

3. **Customizar análises** - Editar scripts em `R/analysis/`

4. **Integrar com outras ferramentas** - Exportar para Excel, Power BI, etc.

---

## Recursos Adicionais

- **FAQ:** [`FAQ_PIPELINE_V3.md`](FAQ_PIPELINE_V3.md)
- **Migração v2→v3:** [`MIGRATION_V2_TO_V3.md`](MIGRATION_V2_TO_V3.md)
- **Documentação técnica:** [`pipeline_v3_usage.md`](pipeline_v3_usage.md)
- **README principal:** [`../README.md`](../README.md)

---

**Parabéns! 🎉**

Você completou o tutorial e agora tem um sistema completo de análise de FIIs rodando!

---

**Versão:** 3.0.0
**Data:** 2026-03-21
**Status:** ✅ Completo
