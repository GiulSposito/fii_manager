# FII Manager - Sistema de Gestão de Portfólio de FIIs

Sistema R para gestão, análise e visualização de portfólio de Fundos de Investimento Imobiliário (FIIs) brasileiros.

## 🚀 Novo: Pipeline Híbrido em Desenvolvimento

**Status atual:** Fase 1 (Fundação) ✅ Completa

Estamos implementando um pipeline híbrido de coleta de dados que combina o melhor de múltiplas fontes:

- ⚡ **60x mais rápido** na coleta de proventos (30min → 30seg)
- 🔄 **3x mais rápido** no pipeline completo (45min → <15min)
- 🛡️ **8x mais confiável** (40% falhas → <5% falhas)
- 📊 **Novos dados**: Indicadores fundamentalistas (P/VP, vacância, etc.)
- 🏗️ **Arquitetura modular**: Código limpo, testável, e manutenível

### Progresso

```
Fase 1: Fundação                     ████████████████████ 100% ✅
Fase 2: Collectors Principais        ░░░░░░░░░░░░░░░░░░░░   0%
Fase 3: Collectors Complementares    ░░░░░░░░░░░░░░░░░░░░   0%
Fase 4: Orquestração                 ░░░░░░░░░░░░░░░░░░░░   0%
Fase 5: Validação                    ░░░░░░░░░░░░░░░░░░░░   0%
Fase 6: Documentação e Testes        ░░░░░░░░░░░░░░░░░░░░   0%
Fase 7: Migração para Produção       ░░░░░░░░░░░░░░░░░░░░   0%
```

📖 **Documentação:** Ver [`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md) e [`docs/PHASE1_FOUNDATION.md`](docs/PHASE1_FOUNDATION.md)

## 📋 Visão Geral

Este projeto é um sistema completo de análise de portfólio de FIIs que:

1. **Importa dados** de múltiplas fontes (Google Sheets, APIs, web scraping)
2. **Processa e limpa** dados financeiros brasileiros
3. **Analisa performance** de portfólio e FIIs individuais
4. **Visualiza resultados** em dashboards e relatórios

## 🏗️ Arquitetura

### Pipeline Atual (Produção)

```
Google Sheets → Portfolio
     ↓
Yahoo Finance → Quotations
     ↓
fiis.com.br  → Proventos (lento, ~30 min)
     ↓
Lupa API     → Metadata FIIs
     ↓
Análises e Dashboards
```

**Problemas:** Lento, frágil, código duplicado

### Pipeline Híbrido (Em Desenvolvimento)

```
Google Sheets     → Portfolio (único com integração sheets)
     ↓
Status Invest API → Proventos (1 request batch, 60x mais rápido!)
     ↓
fiis.com.br Lupa  → Metadata FIIs (538 FIIs, 22 campos únicos)
     ↓
Status Invest Web → Indicadores (P/VP, vacância, etc.)
     ↓
Yahoo Finance     → Cotações históricas
     ↓
Validação Cross-Source
     ↓
Análises e Dashboards
```

**Benefícios:** Rápido, robusto, modular, novos dados

## 📁 Estrutura do Projeto

```
fii_manager/
├── R/
│   ├── collectors/          # NOVO: Coletores modulares (Fase 2+)
│   ├── utils/              # NOVO: Utilidades compartilhadas (Fase 1 ✅)
│   │   ├── brazilian_parsers.R    # Parse números/datas BR
│   │   ├── http_client.R          # HTTP client httr2
│   │   ├── logging.R              # Logging estruturado
│   │   └── persistence.R          # Persistência RDS
│   ├── validators/         # NOVO: Validação de dados (Fase 5)
│   ├── pipeline/           # Pipelines de orquestração
│   │   ├── main_portfolio.R       # Pipeline produção atual
│   │   └── hybrid_pipeline.R      # NOVO: Pipeline híbrido (Fase 4)
│   ├── import/             # Importadores de dados
│   ├── transform/          # Transformações de dados
│   ├── analysis/           # Scripts de análise
│   ├── api/                # Integrações com APIs
│   └── dashboard/          # Dashboards RMarkdown
│
├── config/                 # NOVO: Configuração (Fase 1 ✅)
│   └── pipeline_config.yaml
│
├── data/                   # Dados (gitignored)
│   ├── portfolio.rds
│   ├── income.rds
│   ├── quotations.rds
│   ├── fiis.rds
│   ├── .cache/            # NOVO: Cache de requests
│   └── .logs/             # NOVO: Logs de execução
│
├── tests/                  # NOVO: Testes (Fase 1 ✅)
│   └── test_parsers.R
│
├── docs/                   # NOVO: Documentação (Fase 1 ✅)
│   ├── IMPLEMENTATION_STATUS.md
│   └── PHASE1_FOUNDATION.md
│
├── CLAUDE.md              # Instruções para Claude Code
└── README.md              # Este arquivo
```

## 🚀 Quick Start

### Pipeline Atual (Produção)

```r
# Pipeline completo
source("R/pipeline/main_portfolio.R")

# Ou individual
source("R/import/portfolioGoogleSheets.R")
portfolio <- updatePortfolio()

source("R/import/pricesYahoo.R")
prices <- updatePortfolioPrices(portfolio)

source("R/import/proventos.R")
proventos <- scrapProventos(portfolio$ticker)
```

### Componentes da Fase 1 (Novo)

```r
# Parsers brasileiros
source("R/utils/brazilian_parsers.R")
parse_br_number("R$ 1.234,56")  # 1234.56
parse_br_date("15/03/2026")     # Date: 2026-03-15

# Logging
source("R/utils/logging.R")
logger <- create_logger(level = "INFO")
logger$info("Pipeline iniciado")

# HTTP Client
source("R/utils/http_client.R")
client <- create_http_client(config, logger)
resp <- client$get("/api/endpoint")

# Persistência
source("R/utils/persistence.R")
save_incremental(new_data, "data/income.rds", dedup_columns = c("ticker", "data"))
```

### Exemplos e Testes

```r
# Ver exemplo completo
source("R/utils/example_usage.R")

# Executar testes
source("tests/test_parsers.R")
```

## 📦 Dependências

### Core (Já existentes)

```r
library(tidyverse)      # dplyr, tidyr, ggplot2, etc.
library(lubridate)      # Date handling
library(rvest)          # Web scraping
library(googlesheets4)  # Google Sheets
library(jsonlite)       # JSON
library(plotly)         # Interactive plots
```

### Novas (Pipeline Híbrido)

```r
install.packages("httr2")      # HTTP client moderno
install.packages("yaml")       # YAML config
install.packages("testthat")   # Unit testing
```

## 📊 Dados

### Arquivos RDS Principais

| Arquivo | Descrição | Colunas | Schema |
|---------|-----------|---------|--------|
| `portfolio.rds` | Posições do portfólio | 7 | date, ticker, volume, price, taxes, value, portfolio |
| `income.rds` | Proventos históricos | 6 | ticker, rendimento, data_base, data_pagamento, cota_base, dy |
| `quotations.rds` | Cotações históricas | 3 | ticker, price, date |
| `fiis.rds` | Metadata FIIs (Lupa) | 22 | ticker, nome, segmento, ... |
| `fii_indicators.rds` | **NOVO** Indicadores fundamentalistas | 12 | ticker, p_vp, vacancia, ... |

**Importante:** Arquivos em `data/` são **gitignored** (dados sensíveis de portfólio).

## 🔍 Fontes de Dados

### Atuais (Produção)

| Fonte | Dados | Método | Performance |
|-------|-------|--------|-------------|
| Google Sheets | Portfolio | API (googlesheets4) | ✅ Rápido |
| Yahoo Finance | Cotações | API (quantmod) | ✅ Rápido |
| fiis.com.br | Proventos | Web scraping | ⚠️ Lento (30 min) |
| Lupa de FIIs | Metadata | API (AJAX) | ⚠️ Auth expira |

### Pipeline Híbrido (Em Desenvolvimento)

| Fonte | Dados | Método | Performance |
|-------|-------|--------|-------------|
| Google Sheets | Portfolio | API (googlesheets4) | ✅ Rápido |
| Status Invest | Proventos | **API batch** | ⚡ Muito rápido (30s) |
| Status Invest | Indicadores | Web scraping | ✅ Médio (rate limited) |
| Lupa de FIIs | Metadata | API (AJAX) | ✅ Cache 7 dias |
| Yahoo Finance | Cotações | API (quantmod) | ✅ Rápido |

## 📈 Análises Disponíveis

### Scripts de Análise (`R/analysis/`)

- `nova_analise_proventos.R` - Análise de proventos
- `retorno_portfolio.R` - Retorno do portfólio
- `portfolio_analysis_*.R` - Análises históricas
- `rebalance.R` - Rebalanceamento de carteira
- `return_time.R` - Tempo de retorno de investimento

### Dashboards (`R/dashboard/`)

- `portfolio.Rmd` - Dashboard de portfólio
- `fii_performance.Rmd` - Performance de FIIs

## 🧪 Testes

```r
# Fase 1: Parsers brasileiros
source("tests/test_parsers.R")

# Fase 6: Testes de integração (futuro)
source("tests/test_integration.R")
```

**Meta:** 80% de cobertura antes da Fase 7

## 📝 Documentação

### Guias

- **[CLAUDE.md](CLAUDE.md)** - Instruções para Claude Code
- **[IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md)** - Status do pipeline híbrido
- **[PHASE1_FOUNDATION.md](docs/PHASE1_FOUNDATION.md)** - Documentação da Fase 1

### Guides Futuros (Fase 6)

- `docs/PIPELINE_GUIDE.md` - Como executar o pipeline
- `docs/AUTH_REFRESH_GUIDE.md` - Como renovar credenciais
- `docs/TROUBLESHOOTING.md` - Problemas comuns

## 🔐 Autenticação

### Google Sheets

```r
library(googlesheets4)
gs4_auth()  # Primeira vez
```

### fiis.com.br (necessário para pipeline atual)

```bash
# .Renviron
FIISCOM_COOKIE="..."
FIISCOM_NONCE="..."
```

**Nota:** Pipeline híbrido usa Status Invest como primário, reduzindo dependência de auth do fiis.com.br.

## 🎯 Performance

### Comparação: Atual vs Híbrido

| Métrica | Atual | Target Híbrido | Melhoria |
|---------|-------|----------------|----------|
| **Tempo total** | ~45 min | <15 min | **3x** |
| **Income collection** | ~30 min | <30 seg | **60x** |
| **API calls (income)** | 464 | 1 | **99.8% redução** |
| **Auth failures** | ~40% | <5% | **8x menos** |
| **Memory usage** | ~500 MB | ~300 MB | **40% menos** |

### Benchmarks (Fase 1)

```r
# Parse 1000 números brasileiros
bench::mark(parse_br_number(valores_br))
# ~5ms (rápido)

# Parse 1000 datas brasileiras
bench::mark(parse_br_date(datas_br))
# ~15ms (rápido)
```

## 🛠️ Desenvolvimento

### Contribuindo

1. Criar branch para feature/fix
2. Implementar com testes
3. Atualizar documentação
4. Fazer PR

### Code Style

- **Naming:** camelCase para funções, snake_case para variáveis
- **Indentação:** 2 espaços
- **Pipe:** `%>%` (legacy) ou `|>` (novo)
- **Comments:** Roxygen2 para funções públicas

### Roadmap

- [x] **Fase 1:** Fundação (parsers, HTTP, logging, persistence) - ✅ Completa
- [ ] **Fase 2:** Collectors principais (income, portfolio)
- [ ] **Fase 3:** Collectors complementares (lupa, indicators, quotations)
- [ ] **Fase 4:** Orquestração (hybrid_pipeline.R)
- [ ] **Fase 5:** Validação (schema, quality, consistency)
- [ ] **Fase 6:** Documentação e testes E2E
- [ ] **Fase 7:** Migração para produção

**Estimativa total:** 7 semanas

## 📊 Status do Projeto

- **Versão produção:** 1.0 (pipeline2023.R)
- **Versão desenvolvimento:** 2.0-alpha (pipeline híbrido)
- **Fase atual:** 1 de 7 ✅
- **Progresso geral:** 14%

## 🤝 Suporte

- **Issues:** GitHub Issues (se configurado)
- **Documentação:** `docs/`
- **Exemplos:** `R/utils/example_usage.R`

## 📄 Licença

Projeto privado de gestão de portfólio pessoal.

---

**Última atualização:** 2026-03-20
**Versão:** 2.0-alpha (Fase 1 completa)
**Autor:** Projeto FII Manager
