# Análise Comparativa dos Pipelines de Coleta de Dados de FIIs

## Visão Geral

Este documento compara os três pipelines de coleta de dados implementados no projeto:

1. **fiis.com.br** (Pipeline 2023) - `R/pipeline/pipeline2023.R`
2. **Status Invest - Proventos** - `R/_draft/statusinvest_proventos.R`
3. **Status Invest - Indicadores** - `R/_draft/statusinvest_indicators.R`

## Arquitetura Geral

### Diagrama Comparativo

```
┌─────────────────────────────────────────────────────────────────┐
│                    PIPELINE fiis.com.br (2023)                   │
├─────────────────────────────────────────────────────────────────┤
│ Google Sheets → Portfolio                                        │
│ Lupa API      → Lista FIIs                                       │
│ Incomes API   → Proventos (por ticker, iterado)                 │
│ Quotes API    → Cotações (por ticker, iterado)                  │
│                 ↓                                                │
│            4 arquivos RDS                                        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│              PIPELINE Status Invest - Proventos                  │
├─────────────────────────────────────────────────────────────────┤
│ API pública   → Todos proventos (batch, filtro período)         │
│                 ↓                                                │
│            Tibble diretamente                                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│             PIPELINE Status Invest - Indicadores                 │
├─────────────────────────────────────────────────────────────────┤
│ Web Scraping  → Indicadores + Cotação atual (por ticker)        │
│                 ↓                                                │
│            Tibble diretamente                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Padrão de Arquitetura

| Aspecto | fiis.com.br | SI Proventos | SI Indicadores |
|---------|-------------|--------------|----------------|
| **Fontes de dados** | 4 endpoints diferentes | 1 endpoint | 1 página HTML por FII |
| **Orquestração** | Pipeline completo multi-etapas | Função única | Função única |
| **Modularização** | Alta (4 arquivos source) | Baixa (single file) | Baixa (single file) |
| **Dependências entre etapas** | Sim (portfolio → FII list → dados) | Não | Não |
| **Persistência** | RDS (4 arquivos) | Retorno direto | Retorno direto |

## Tecnologias e Bibliotecas

### Stack Tecnológico

```r
# Pipeline fiis.com.br
httr            # HTTP client (versão antiga)
jsonlite        # JSON parsing
googlesheets4   # Google Sheets
purrr::safely() # Error handling
rvest           # Web scraping (importFIIList)

# Pipeline Status Invest - Proventos
httr2           # HTTP client (moderna)
jsonlite        # JSON parsing

# Pipeline Status Invest - Indicadores
rvest           # Web scraping
xml2            # HTML/XML parsing
stringr         # String manipulation
```

### Evolução Tecnológica

**httr → httr2**

```r
# ANTIGO (fiis.com.br)
resp <- httr::GET(url, add_headers(...))
data <- content(resp, as="text") %>% fromJSON()

# NOVO (Status Invest)
resp <- request(url) %>%
  req_url_query(...) %>%
  req_user_agent(...) %>%
  req_perform() %>%
  resp_body_json()
```

**Vantagens httr2**:
- Sintaxe de pipe nativa
- Melhor tratamento de erros
- Performance superior
- API mais consistente

## Métodos de Acesso aos Dados

### 1. APIs REST (JSON)

**fiis.com.br** e **Status Invest Proventos** usam APIs REST.

#### Comparação de Autenticação

```r
# fiis.com.br - COMPLEXO
api_headers <- add_headers(
  'authority' = 'fiis.com.br',
  'accept' = 'application/json, text/plain, */*',
  'cookie' = '__gads=ID=...; __gpi=UID=...; [MUITO LONGO]',
  'x-fiis-nonce' = '61495f60b533cc40ad822e054998a3190ea9bca0d94791a1da',
  'user-agent' = 'Mozilla/5.0 ...',
  'sec-ch-ua' = '...',
  'sec-fetch-dest' = 'empty',
  # ... mais 10 headers
)

# Status Invest - SIMPLES
req_user_agent("Mozilla/5.0 (compatible; R HTTR2 request)")
```

#### Padrão de Request

| Característica | fiis.com.br | Status Invest |
|----------------|-------------|---------------|
| **Headers obrigatórios** | ~15 headers | 1 header |
| **Cookies** | Sim (expira) | Não |
| **Nonce/Token** | Sim (x-fiis-nonce) | Não |
| **Manutenção** | Alta (requer atualização frequente) | Baixa (estável) |
| **Documentação** | Não oficial | Não oficial |

### 2. Web Scraping (HTML)

**Status Invest Indicadores** usa web scraping.

#### Estrutura de Parsing

```r
# Estratégia: Localizar containers, extrair cards estruturados
html <- read_html(url)
containers <- html_elements(html, ".top-info")  # Blocos principais
cards <- html_elements(container, ".info")      # Cards individuais

# Extração estruturada
tibble(
  name      = cards %>% html_element("h3.title") %>% html_text2(),
  value_raw = cards %>% html_element("strong.value") %>% html_text2(),
  # ...
)
```

#### Fragilidade

| Aspecto | API REST | Web Scraping |
|---------|----------|--------------|
| **Estabilidade** | ✅ Estrutura de dados consistente | ❌ HTML pode mudar a qualquer momento |
| **Versionamento** | ✅ APIs têm versões (v1, v2) | ❌ Sem versão |
| **Breaking changes** | ⚠️ Raros mas acontecem | ❌ Frequentes |
| **Facilidade manutenção** | ✅ Erros claros (status codes) | ❌ Silent failures (seletores não acham) |

## Padrões Comuns

### 1. Tratamento de Formato Brasileiro

**TODOS os pipelines** lidam com formato numérico e datas brasileiras.

```r
# ============================================
# PADRÃO 1: Parse Numérico Brasileiro
# ============================================

# fiis.com.br (implícito no fromJSON)
mutate(across(c(rendimento, cota_base, dy), as.numeric))

# Status Invest - Proventos (explícito)
parse_number(x, locale = locale(decimal_mark = ","))

# Status Invest - Indicadores (complexo)
parse_br_number <- function(x) {
  x %>%
    str_replace_all("R\\$\\s*", "") %>%
    str_replace_all("%", "") %>%
    str_replace_all("\\s", " ") %>%
    str_squish() %>%
    readr::parse_number(locale = locale(decimal_mark = ",", grouping_mark = "."))
}

# ============================================
# PADRÃO 2: Parse de Datas
# ============================================

# fiis.com.br - formato YYYY-MM-DD (vem da API)
mutate(across(starts_with("data"), ymd))

# Status Invest - Proventos - formato DD/MM/YYYY
mutate(across(baseDate:payDate, dmy))

# Status Invest - Quotations (no pipeline antigo)
mutate(date = dmy_hm(date))  # DD/MM/YYYY HH:MM
```

**Padrão unificado sugerido**:

```r
# Criar funções helpers compartilhadas
.parse_br_number <- function(x) {
  readr::parse_number(x, locale = locale(decimal_mark = ",", grouping_mark = "."))
}

.parse_br_date <- function(x) {
  lubridate::dmy(x)
}

.parse_br_datetime <- function(x) {
  lubridate::dmy_hm(x)
}
```

### 2. Error Handling com purrr::safely()

**fiis.com.br** usa pattern `safely()` consistentemente:

```r
# Padrão de uso
safeGetIncome <- safely(getIncomes)

resp_income <- fii_list |>
  mutate(income_call = map(ticker, safeGetIncome, .progress = T)) |>
  mutate(income = map(income_call, function(.x) .x$result))

# Estrutura de resposta
# $result - dados ou NULL
# $error  - erro ou NULL
```

**Status Invest pipelines** não implementam, mas deveriam:

```r
# Recomendação
safe_get_earnings <- safely(get_fii_earnings)
safe_get_cards <- safely(get_fii_cards)
```

### 3. Progress Tracking

**fiis.com.br** usa `.progress = T`:

```r
mutate(income_call = map(ticker, safeGetIncome, .progress = T))
```

**Status Invest** não implementa (mas deveria para batch operations).

### 4. Retorno Status Code

**Ambas APIs REST** checam status:

```r
# Padrão comum
if(resp$status_code != 200) return(NULL)
```

## Diferenças Estruturais

### 1. Padrão de Iteração

#### fiis.com.br - Iteração Individual

```r
# Um request POR ticker
resp_income <- fii_list |>
  mutate(income_call = map(ticker, safeGetIncome, .progress = T))

# Para 300 FIIs = 300 requests
# Tempo: ~5-10 minutos (com rate limiting)
```

#### Status Invest Proventos - Batch Request

```r
# Um request para TODOS os FIIs
proventos <- get_fii_earnings(
  filter = "",  # vazio = todos
  start = "2024-01-01",
  end = "2025-03-20"
)

# Para 300 FIIs = 1 request
# Tempo: ~2-5 segundos
```

**Impacto**:

| Métrica | fiis.com.br | Status Invest |
|---------|-------------|---------------|
| **Requests** | N (um por FII) | 1 (batch) |
| **Tempo** | O(N) | O(1) |
| **Rate limit risk** | Alto | Baixo |
| **Complexidade** | Alta (map + safely) | Baixa (chamada direta) |

### 2. Parsing JSON

#### fiis.com.br - Multi-level Parsing

```r
# PROVENTOS - Double parsing
data_resp <- resp |>
  content(as="text") |>
  fromJSON() |>        # Parse 1
  fromJSON()           # Parse 2

# COTAÇÕES - Triple parsing
quotations <- resp |>
  content(as="text") |>
  fromJSON() |>        # Parse 1
  fromJSON() |>        # Parse 2
  pull(quotations) |>
  fromJSON() |>        # Parse 3
  as_tibble()
```

**Por quê?** A API retorna JSON stringificado dentro de JSON.

#### Status Invest - Single parsing

```r
# Parsing direto
data <- req %>% resp_body_json()
combined <- bind_rows(data$dateCom, data$datePayment)
```

**Complexidade**: Status Invest tem estrutura JSON mais limpa.

### 3. Estrutura de Dados de Saída

#### fiis.com.br - Granular (múltiplos arquivos)

```r
# 4 arquivos RDS separados
saveRDS(fiis, "./data/fiis.rds")           # Lista de FIIs
saveRDS(income, "./data/income.rds")       # Proventos
saveRDS(quotations, "./data/quotations.rds") # Cotações
saveRDS(port, "./data/portfolio.rds")      # Portfolio

# Vantagem: Separação de concerns
# Desvantagem: Requer joins para análises integradas
```

#### Status Invest - Flat (retorno direto)

```r
# Retorna tibble diretamente
proventos <- get_fii_earnings(...)
indicators <- get_fii_cards(...)

# Vantagem: Flexibilidade (usuário decide onde salvar)
# Desvantagem: Requer orquestração externa
```

### 4. Transformação de Dados

#### fiis.com.br - Transformação na Fonte

```r
# Transformações aplicadas dentro da função de coleta
getIncomes <- function(ticker) {
  # ... coleta ...
  income <- as_tibble(data_resp$incomes) |>
    mutate(
      across(c(rendimento, cota_base, dy), as.numeric),
      across(starts_with("data"), ymd)
    )
  return(income)
}

# Dados já vêm transformados
```

#### Status Invest - Transformação Separada

```r
# Pipeline explícito de transformação
get_fii_earnings <- function(filter, start, end) {
  # ... coleta ...
  combined <- bind_rows(data$dateCom, data$datePayment)

  # Transformações em pipeline separado
  combined |>
    select(...) |>
    set_names(...) |>
    mutate(across(...)) |>
    mutate(across(...))
}

# Mais visível, mas acoplado
```

#### Status Invest Indicadores - Transformação Incremental

```r
# Transformação em múltiplas etapas
extract_cards <- function(container) {
  cards <- html_elements(container, ".info")

  # Etapa 1: Extração raw
  raw_data <- tibble(
    name = cards %>% html_element("h3.title") %>% html_text2(),
    value_raw = cards %>% html_element("strong.value") %>% html_text2(),
    # ...
  )

  # Etapa 2: Transformação
  raw_data %>%
    mutate(
      value_num = parse_br_number(value_raw),
      value_is_pct = has_percent(value_raw),
      # ...
    )
}

# Mais complexo, mas mais flexível
```

## Dados Coletados

### Matriz de Dados

| Tipo de Dado | fiis.com.br | SI Proventos | SI Indicadores |
|--------------|-------------|--------------|----------------|
| **Portfolio** | ✅ Google Sheets | ❌ | ❌ |
| **Lista de FIIs** | ✅ Lupa API | ❌ | ❌ |
| **Proventos históricos** | ✅ Por ticker | ✅ Batch | ❌ |
| **Cotações históricas** | ✅ Por ticker | ❌ | ❌ |
| **Cotação atual** | ❌ | ❌ | ✅ |
| **Indicadores fundamentalistas** | ❌ | ❌ | ✅ |
| **P/VP** | ❌ | ❌ | ✅ |
| **Vacância** | ❌ | ❌ | ✅ |
| **Dividend Yield** | ✅ Por provento | ✅ Por provento | ✅ Agregado |
| **Valor Patrimonial** | ✅ (Lupa) | ❌ | ✅ |

### Complementaridade

Os pipelines são **complementares**:

```r
# Pipeline ideal combinado
portfolio      <- updatePortfolio()           # fiis.com.br
fiis_list      <- importLupa()                # fiis.com.br
proventos      <- get_fii_earnings(...)       # Status Invest ⭐
quotations     <- getQuotations(...)          # fiis.com.br (histórico)
indicators     <- get_fii_cards(...)          # Status Invest ⭐
```

## Performance

### Benchmark Estimado

**Coleta de proventos de 300 FIIs:**

| Pipeline | Requests | Tempo Estimado | Rate Limit Risk |
|----------|----------|----------------|-----------------|
| fiis.com.br | 300 | 5-10 min | Alto |
| Status Invest | 1 | 2-5 seg | Baixo |

**Coleta de indicadores de 300 FIIs:**

| Pipeline | Requests | Tempo Estimado | Rate Limit Risk |
|----------|----------|----------------|-----------------|
| SI Indicators | 300 | 10-15 min (com delays) | Médio |
| fiis.com.br | N/A | - | - |

### Gargalos

**fiis.com.br:**
- ❌ Iteração N vezes
- ❌ Sem paralelização
- ❌ Progress sequencial

**Status Invest Proventos:**
- ✅ Batch único
- ✅ Rápido

**Status Invest Indicators:**
- ❌ HTML parsing lento
- ❌ Iteração N vezes necessária
- ⚠️ Requer delays (rate limiting manual)

## Robustez e Manutenção

### Escala de Fragilidade

```
Mais Estável ←──────────────────────────→ Mais Frágil

Status Invest    fiis.com.br      Status Invest
Proventos        APIs REST        Indicadores
    ✅              ⚠️                ❌

Sem auth       Auth complexa    HTML parsing
API pública    que expira       que pode mudar
```

### Fatores de Fragilidade

| Fator | fiis.com.br | SI Proventos | SI Indicadores |
|-------|-------------|--------------|----------------|
| **Cookies expiram** | ❌ Sim | ✅ Não | ✅ Não |
| **Nonce expira** | ❌ Sim | ✅ Não | ✅ Não |
| **HTML pode mudar** | ✅ Não | ✅ Não | ❌ Sim |
| **API pode mudar** | ⚠️ Sim | ⚠️ Sim | ✅ Não (não é API) |
| **Requer atualização manual** | ❌ Frequente | ✅ Rara | ⚠️ Ocasional |

## Padrões de Código

### Nomenclatura de Funções

| Padrão | Exemplo | Pipeline |
|--------|---------|----------|
| **Verbo + Substantivo** | `getIncomes()`, `getQuotations()` | fiis.com.br |
| **Verbo + Substantivo** | `updatePortfolio()` | fiis.com.br |
| **Verbo + Substantivo** | `importLupa()` | fiis.com.br |
| **get + snake_case** | `get_fii_earnings()` | Status Invest |
| **get + snake_case** | `get_fii_cards()` | Status Invest |

**Inconsistência**: fiis.com.br usa camelCase, Status Invest usa snake_case.

### Organização de Código

**fiis.com.br - Modular**:
```
R/
├── pipeline/
│   └── pipeline2023.R          # Orquestração
├── import/
│   └── portfolioGoogleSheets.R # Função específica
└── api/
    ├── fii_incomes.R           # Função específica
    ├── fii_quotations.R        # Função específica
    └── import_lupa_2023.R      # Função específica
```

**Status Invest - Monolítico**:
```
R/_draft/
├── statusinvest_proventos.R    # Tudo em um arquivo
└── statusinvest_indicators.R   # Tudo em um arquivo
```

### Helpers e Utilities

**fiis.com.br**:
```r
# Helper privado (prefixo .)
.parseRealValue <- function(x) { ... }

# Usado internamente
portfolio <- spreadsheet %>%
  mutate(price = .parseRealValue(price))
```

**Status Invest**:
```r
# Helper público
parse_br_number <- function(x) { ... }
clean_title <- function(x) { ... }
has_percent <- function(x) { ... }

# Usado dentro de outras funções
```

**Convenção recomendada**: Usar `.` prefix para funções privadas.

## Oportunidades de Unificação

### 1. Parser Brasileiro Centralizado

```r
# Criar R/utils/brazilian_parsers.R
.br_locale <- locale(decimal_mark = ",", grouping_mark = ".")

parse_br_number <- function(x, remove_currency = TRUE, remove_percent = TRUE) {
  if(remove_currency) x <- str_remove_all(x, "R\\$\\s*")
  if(remove_percent) x <- str_remove_all(x, "%")

  x %>%
    str_replace_all("\\s", " ") %>%
    str_squish() %>%
    readr::parse_number(locale = .br_locale)
}

parse_br_date <- function(x) lubridate::dmy(x)
parse_br_datetime <- function(x) lubridate::dmy_hm(x)

# Usar em todos os pipelines
```

### 2. Error Handling Wrapper

```r
# Criar R/utils/safe_wrappers.R
make_safe_api_call <- function(fn, ticker, ...) {
  safe_fn <- purrr::safely(fn)
  result <- safe_fn(ticker, ...)

  if(!is.null(result$error)) {
    warning(glue("Failed for {ticker}: {result$error$message}"))
    return(NULL)
  }

  result$result
}

# Usar
income <- map(tickers, ~make_safe_api_call(getIncomes, .x))
```

### 3. HTTP Client Unificado

```r
# Migrar tudo para httr2
# Criar R/utils/http_clients.R

fiis_com_br_client <- function(endpoint) {
  request(glue("https://fiis.com.br/wp-json/fiis/v1/{endpoint}")) %>%
    req_headers(
      `authority` = 'fiis.com.br',
      `accept` = 'application/json, text/plain, */*',
      # ... headers compartilhados
    ) %>%
    req_user_agent("...")
}

statusinvest_client <- function(path) {
  request(glue("https://statusinvest.com.br/{path}")) %>%
    req_user_agent("Mozilla/5.0 (compatible; R HTTR2 request)")
}
```

### 4. Módulo de Persistência

```r
# R/utils/persistence.R
save_pipeline_data <- function(data, name, dir = "data") {
  path <- file.path(dir, glue("{name}.rds"))
  saveRDS(data, path)
  message(glue("✓ Saved {name} to {path}"))
  invisible(data)
}

load_pipeline_data <- function(name, dir = "data") {
  path <- file.path(dir, glue("{name}.rds"))
  readRDS(path)
}

# Usar
proventos %>% save_pipeline_data("income")
income <- load_pipeline_data("income")
```

## Recomendações

### 1. Pipeline Híbrido Ideal

```r
# R/pipeline/unified_pipeline.R

# Etapa 1: Portfolio e Lista de FIIs (fiis.com.br)
portfolio <- updatePortfolio()          # Google Sheets
fiis_list <- importLupa()               # fiis.com.br API
tickers <- unique(portfolio$ticker)

# Etapa 2: Proventos (Status Invest - mais rápido)
proventos <- get_fii_earnings(
  filter = "",
  start = format(Sys.Date() - months(12), "%Y-%m-%d"),
  end = format(Sys.Date(), "%Y-%m-%d")
) %>%
  filter(ticker %in% tickers)

# Etapa 3: Cotações históricas (fiis.com.br - único com histórico)
quotations <- tickers %>%
  map(safely(getQuotations)) %>%
  map("result") %>%
  bind_rows()

# Etapa 4: Indicadores (Status Invest - único com P/VP, vacância, etc)
indicators <- tibble(ticker = tickers) %>%
  mutate(
    url = glue("https://statusinvest.com.br/fundos-imobiliarios/{ticker}"),
    data = map(url, possibly(get_fii_cards, NULL), .progress = T)
  ) %>%
  unnest(data)

# Salvar tudo
save_pipeline_data(portfolio, "portfolio")
save_pipeline_data(fiis_list, "fiis")
save_pipeline_data(proventos, "income")
save_pipeline_data(quotations, "quotations")
save_pipeline_data(indicators, "fii_indicators")
```

### 2. Modularização

```
R/
├── collectors/              # Novo: coletores unificados
│   ├── fiis_com_br.R       # API fiis.com.br
│   ├── status_invest.R     # APIs Status Invest
│   └── google_sheets.R     # Portfolio
├── parsers/                # Novo: parsers compartilhados
│   └── brazilian.R         # Formatos BR
├── utils/                  # Novo: utilidades
│   ├── http_clients.R
│   ├── persistence.R
│   └── error_handling.R
└── pipeline/
    └── unified_pipeline.R  # Orquestração principal
```

### 3. Testing

```r
# tests/testthat/test-parsers.R
test_that("parse_br_number works", {
  expect_equal(parse_br_number("R$ 1.234,56"), 1234.56)
  expect_equal(parse_br_number("95,2%"), 95.2)
})

# tests/testthat/test-collectors.R
test_that("get_fii_earnings returns valid data", {
  proventos <- get_fii_earnings("ALZR11", "2024-01-01", "2024-12-31")
  expect_s3_class(proventos, "tbl_df")
  expect_true("ticker" %in% names(proventos))
})
```

### 4. Configuração Centralizada

```r
# config/pipelines.yml
fiis_com_br:
  base_url: "https://fiis.com.br/wp-json/fiis/v1/"
  rate_limit: 0.5  # segundos entre requests
  timeout: 30

status_invest:
  base_url: "https://statusinvest.com.br/"
  rate_limit: 2  # segundos entre scraping
  timeout: 30

# R/config.R
config <- yaml::read_yaml("config/pipelines.yml")
```

## Conclusão

### Pontos Fortes de Cada Pipeline

**fiis.com.br**:
- ✅ Histórico completo de cotações
- ✅ Lista completa de FIIs (Lupa)
- ✅ Integração com Google Sheets
- ✅ Pipeline completo end-to-end

**Status Invest - Proventos**:
- ✅ Performance excelente (batch)
- ✅ Sem autenticação complexa
- ✅ Código simples e limpo
- ✅ Manutenção baixa

**Status Invest - Indicadores**:
- ✅ Únicos com P/VP, vacância, VP
- ✅ Dados fundamentalistas ricos
- ✅ Snapshot atual do mercado

### Estratégia Recomendada

**Curto Prazo**:
1. Manter fiis.com.br para cotações históricas e lista de FIIs
2. Migrar coleta de proventos para Status Invest (melhor performance)
3. Adicionar coleta de indicadores Status Invest ao pipeline

**Médio Prazo**:
1. Unificar parsers brasileiros
2. Migrar todo código para httr2
3. Criar módulo de persistência compartilhado
4. Adicionar testes automatizados

**Longo Prazo**:
1. Monitorar estabilidade das APIs
2. Implementar cache inteligente
3. Criar sistema de fallback (se Status Invest falhar, usar fiis.com.br)
4. Considerar outras fontes de dados (B3, CVM)
