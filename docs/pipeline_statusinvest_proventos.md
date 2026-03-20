# Pipeline Status Invest - Proventos

## Visão Geral

Pipeline moderno de coleta de **proventos** (rendimentos e dividendos) de FIIs utilizando a API pública do site **statusinvest.com.br**. Implementado no arquivo `R/_draft/statusinvest_proventos.R`.

Este pipeline substitui/complementa a coleta de proventos do pipeline antigo (fiis.com.br).

## Arquitetura

### Fluxo

```
statusinvest.com.br API
      ↓
GET /fii/getearnings
      ↓
JSON Response
      ↓
Tibble estruturado
```

### Arquivo Principal

- `R/_draft/statusinvest_proventos.R`

## Componente Principal

### Função: `get_fii_earnings(filter, start, end)`

Coleta dados de proventos de FIIs em um intervalo de datas específico.

#### Parâmetros

- **filter** (string): Código do ticker (ex: "ALZR11") ou vazio para todos os FIIs do IFIX
- **start** (string): Data inicial no formato "YYYY-MM-DD"
- **end** (string): Data final no formato "YYYY-MM-DD"

#### Endpoint

```
GET https://statusinvest.com.br/fii/getearnings
```

**Query parameters**:
- `IndiceCode=ifix` - Fixo para FIIs
- `Filter={ticker}` - Ticker específico ou vazio
- `Start={start}` - Data inicial
- `End={end}` - Data final

#### Exemplo de URL

```
# Todos os FIIs do IFIX em um período
https://statusinvest.com.br/fii/getearnings?IndiceCode=ifix&Filter=&Start=2025-09-01&End=2025-11-28

# FII específico
https://statusinvest.com.br/fii/getearnings?IndiceCode=ifix&Filter=ALZR11&Start=2025-09-11&End=2025-11-28
```

## Estrutura de Dados

### JSON Response

A API retorna um objeto com duas listas principais:
- `dateCom` - Proventos organizados por data COM (data base)
- `datePayment` - Proventos organizados por data de pagamento

Ambas contêm os mesmos dados, apenas organizados diferentemente.

### Campos Retornados

| Campo (API) | Campo (Tibble) | Tipo | Descrição |
|-------------|----------------|------|-----------|
| `code` | `ticker` | string | Código do FII |
| `resultAbsoluteValue` | `dividend` | numeric | Valor do provento em R$ |
| `dateCom` | `baseDate` | date | Data base (data COM) |
| `paymentDividend` | `payDate` | date | Data de pagamento |
| `earningType` | `earningType` | string | Tipo do provento |
| `dy` | `dividendYield` | numeric | Dividend Yield (%) |

### Tipos de Proventos

O campo `earningType` pode conter:
- "Rendimento" - Rendimento mensal regular
- "Dividendo" - Dividendo extraordinário
- "Amortização" - Amortização de cotas
- Outros tipos específicos

## Transformações Aplicadas

### 1. Parsing Numérico Brasileiro

```r
readr::parse_number(x, locale = locale(decimal_mark = ","))
```

- Converte strings com vírgula decimal para numeric
- Aplica-se aos campos: `dividend` e `dividendYield`

### 2. Parsing de Datas

```r
lubridate::dmy(date_string)
```

- Converte formato DD/MM/YYYY para objetos Date
- Aplica-se aos campos: `baseDate` e `payDate`

### 3. Renomeação de Campos

Campos são renomeados para seguir convenção do projeto:
- Inglês mais descritivo
- Padrão camelCase consistente

## Implementação Técnica

### Headers HTTP

```r
req_user_agent("Mozilla/5.0 (compatible; R HTTR2 request)")
```

User-agent simples para evitar bloqueios, mas sem necessidade de cookies ou nonces como no pipeline antigo.

### Tecnologia

Utiliza **httr2** (evolução do httr):

```r
req <- request(base_url) %>%
  req_url_query(...) %>%
  req_user_agent(...) %>%
  req_perform()

data <- req %>% resp_body_json()
```

**Vantagens sobre httr**:
- Sintaxe de pipe mais limpa
- Melhor controle de erros
- Performance superior

### Combinação de Listas

```r
combined <- bind_rows(data$dateCom, data$datePayment)
```

Combina as duas listas retornadas pela API (organizadas por data COM e data de pagamento) em um único tibble.

## Exemplo de Uso

```r
source("R/_draft/statusinvest_proventos.R")

# Buscar proventos de um FII específico
proventos_alzr <- get_fii_earnings(
  filter = "ALZR11",
  start = "2024-01-01",
  end = "2024-12-31"
)

# Buscar todos os FIIs do IFIX
proventos_todos <- get_fii_earnings(
  filter = "",  # vazio = todos
  start = "2025-01-01",
  end = "2025-03-20"
)

# Exemplo de resultado
# # A tibble: 12 × 6
#   ticker dividend baseDate   payDate    earningType dividendYield
#   <chr>     <dbl> <date>     <date>     <chr>               <dbl>
# 1 ALZR11     0.95 2024-01-15 2024-01-25 Rendimento           0.85
# 2 ALZR11     0.97 2024-02-15 2024-02-25 Rendimento           0.87
# ...
```

## Comparação com Pipeline Antigo (fiis.com.br)

### Vantagens

| Aspecto | Status Invest | fiis.com.br |
|---------|---------------|-------------|
| **Autenticação** | ✅ Não requer cookies/nonce | ❌ Requer cookies+nonce que expiram |
| **Manutenção** | ✅ API pública estável | ❌ Requer atualização frequente de credenciais |
| **Filtros** | ✅ Filtro por período flexível | ⚠️ Sem filtros de data |
| **Batch requests** | ✅ Pode buscar todos os FIIs de uma vez | ❌ Requer um request por FII |
| **Performance** | ✅ Mais rápido (menos requests) | ❌ Mais lento (N requests) |
| **Biblioteca HTTP** | ✅ httr2 (moderna) | ⚠️ httr (legada) |
| **Simplicidade** | ✅ Código mais limpo | ❌ Muitos headers complexos |

### Desvantagens

| Aspecto | Status Invest | fiis.com.br |
|---------|---------------|-------------|
| **Dados históricos** | ⚠️ Limitado ao que a API retorna | ✅ Histórico completo disponível |
| **Campos extras** | ❌ Menos campos (6 campos) | ✅ Mais campos detalhados |
| **Documentação** | ❌ API não documentada oficialmente | ⚠️ API não documentada |

## Boas Práticas de Uso

### 1. Rate Limiting

Embora a API não exija autenticação, é recomendado:

```r
# Para múltiplas chamadas, adicionar delay
purrr::map(tickers, function(ticker) {
  result <- get_fii_earnings(ticker, start, end)
  Sys.sleep(1)  # 1 segundo entre requests
  result
})
```

### 2. Filtro por Período

Utilizar filtros de data para reduzir payload:

```r
# ✅ BOM: Último ano apenas
get_fii_earnings("", "2025-01-01", "2025-12-31")

# ❌ EVITAR: Período muito longo pode ter response grande
get_fii_earnings("", "2010-01-01", "2025-12-31")
```

### 3. Batch vs Individual

```r
# ✅ EFICIENTE: Um request para todos os FIIs
all_fiis <- get_fii_earnings("", "2025-01-01", "2025-03-01")

# ❌ INEFICIENTE: N requests (um por FII)
results <- map(ticker_list, ~get_fii_earnings(.x, start, end))
```

### 4. Tratamento de Erros

```r
# Usar safely() para robustez
safe_get_earnings <- purrr::safely(get_fii_earnings)

result <- safe_get_earnings("ALZR11", "2025-01-01", "2025-03-01")

if(is.null(result$error)) {
  data <- result$result
} else {
  message("Erro: ", result$error)
}
```

## Pipeline Recomendado

```r
library(tidyverse)
library(lubridate)

source("R/_draft/statusinvest_proventos.R")

# 1. Definir período
end_date <- Sys.Date()
start_date <- end_date - months(12)

# 2. Buscar todos os proventos do IFIX
proventos <- get_fii_earnings(
  filter = "",  # todos os FIIs
  start = format(start_date, "%Y-%m-%d"),
  end = format(end_date, "%Y-%m-%d")
)

# 3. Filtrar apenas FIIs da carteira (opcional)
portfolio <- readRDS("data/portfolio.rds")
tickers_carteira <- unique(portfolio$ticker)

proventos_carteira <- proventos %>%
  filter(ticker %in% tickers_carteira)

# 4. Salvar
saveRDS(proventos_carteira, "data/income.rds")
```

## Dependências

- `httr2` - Requisições HTTP modernas
- `jsonlite` - Parsing JSON
- `tidyverse` - Manipulação de dados (dplyr, purrr)
- `lubridate` - Manipulação de datas

## Status

⚠️ **DRAFT** - Este pipeline está em `R/_draft/` e ainda não está integrado ao pipeline principal.

Para integração futura, considerar:
1. Criar função wrapper que combine com dados existentes
2. Implementar cache para evitar requests repetidos
3. Adicionar logging de erros
4. Integrar ao `main_portfolio.R` ou criar novo pipeline
