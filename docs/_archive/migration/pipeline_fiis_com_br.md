# Pipeline fiis.com.br - Pipeline 2023

## Visão Geral

Pipeline de coleta de dados de FIIs utilizando APIs e web scraping do site **fiis.com.br**. Este é o pipeline mais antigo do projeto, implementado no arquivo `R/pipeline/pipeline2023.R`.

## Arquitetura

### Fluxo Principal

```
Google Sheets → Portfolio
     ↓
Lupa de FIIs → Lista de FIIs
     ↓
APIs fiis.com.br → Proventos + Cotações
     ↓
Arquivos RDS (data/)
```

### Arquivos Envolvidos

1. **Pipeline Principal**: `R/pipeline/pipeline2023.R`
2. **Importadores**:
   - `R/import/portfolioGoogleSheets.R` - Importa carteira do Google Sheets
   - `R/api/import_lupa_2023.R` - Importa lista de FIIs da "Lupa de FIIs"
3. **APIs**:
   - `R/api/fii_incomes.R` - Coleta proventos (rendimentos)
   - `R/api/fii_quotations.R` - Coleta cotações

## Componentes Detalhados

### 1. Importação do Portfolio (`portfolioGoogleSheets.R`)

**Função**: `updatePortfolio()`

**Fonte**: Google Sheets (key: `1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU`)

**Campos importados**:
- `Data` → `date` - Data da operação
- `Ativo` → `ticker` - Código do FII
- `Qtd` → `volume` - Quantidade de cotas
- `Valor` → `price` - Preço unitário
- `Taxas` → `taxes` - Taxas da operação
- `Total` → `value` - Valor total
- `Carteira` → `portfolio` - Nome da carteira

**Saída**: `data/portfolio.rds`

**Tecnologia**: `googlesheets4` package

### 2. Importação da Lupa de FIIs (`import_lupa_2023.R`)

**Função**: `importLupa()`

**Endpoint**: `https://fiis.com.br/wp-json/fiis/v1/lupa_fiis`

**Dados coletados**:
- Ticker, nome, segmento
- Dividend Yield (DY)
- Rendimento (médias 6m, 12m, 36m)
- Patrimônio e número de cotistas
- Data base e data de pagamento
- Cotação base e cotação VP
- Participação no IFIX

**Transformações aplicadas**:
- Remove pontos de separadores de milhar no campo `negocios`
- Converte campos numéricos (DY, rendimentos, patrimônio, etc.)
- Converte datas (formato YMD)
- Converte `last_dividend` para lógico

**Saída**: `data/fiis.rds`

**Headers necessários**:
- User-Agent: Simula navegador Chrome no macOS
- Nonce customizado: `x-fiis-nonce`
- Cookies de sessão completos

### 3. Coleta de Proventos (`fii_incomes.R`)

**Função**: `getIncomes(ticker)`

**Endpoint**: `https://fiis.com.br/wp-json/fiis/v1/funds/{ticker}/incomes`

**Dados retornados**:
- `rendimento` - Valor do provento
- `cota_base` - Cotação base
- `dy` - Dividend Yield
- `data_*` - Datas relacionadas (base, pagamento, etc.)

**Transformações**:
- Converte valores monetários para numérico
- Converte datas usando `ymd()`
- Double parsing JSON (dois níveis)

**Tratamento de erros**:
- Retorna `NULL` se status ≠ 200
- Utiliza `safely()` no pipeline para capturar falhas

**Saída**: `data/income.rds`

### 4. Coleta de Cotações (`fii_quotations.R`)

**Função**: `getQuotations(ticker)`

**Endpoint**: `https://fiis.com.br/wp-json/fiis/v1/funds/{ticker}/quotes`

**Dados retornados**:
- `date` - Data/hora da cotação (formato: DD/MM/YYYY HH:MM)
- Valores de cotação (abertura, fechamento, máxima, mínima)
- Volume negociado

**Transformações**:
- Triple parsing JSON (três níveis)
- Converte data com `dmy_hm()` (data-hora brasileira)

**Tratamento de erros**:
- Retorna `NULL` se status ≠ 200
- Utiliza `safely()` no pipeline para capturar falhas

**Saída**: `data/quotations.rds`

## Pipeline de Execução

```r
# 1. Importa portfolio do Google Sheets
source("./R/import/portfolioGoogleSheets.R")
port <- updatePortfolio()

# 2. Importa lista de FIIs da Lupa
source("./R/api/import_lupa_2023.R")
fiis <- importLupa()

# 3. Filtra FIIs com pagamento >= 2024-01-01
fii_list <- fiis |>
  filter(data_pagamento >= ymd("2024-01-01")) |>
  distinct(ticker) |>
  arrange(ticker)

# 4. Coleta proventos com tratamento de erro
source("./R/api/fii_incomes.R")
safeGetIncome <- safely(getIncomes)

resp_income <- fii_list |>
  mutate(income_call = map(ticker, safeGetIncome, .progress = T)) |>
  mutate(income = map(income_call, function(.x) .x$result))

income <- resp_income |>
  select(ticker, income) |>
  unnest(income)

# 5. Coleta cotações com tratamento de erro
source("./R/api/fii_quotations.R")
safeGetQuotations <- safely(getQuotations)

resp_quotation <- fii_list |>
  mutate(quotation_call = map(ticker, safeGetQuotations, .progress = T)) |>
  mutate(quotation = map(quotation_call, function(.x) .x$result))

quotations <- resp_quotation |>
  select(ticker, quotation) |>
  unnest(quotation)

# 6. Salva todos os dados
saveRDS(fiis, "./data/fiis.rds")
saveRDS(income, "./data/income.rds")
saveRDS(quotations, "./data/quotations.rds")
saveRDS(port, "./data/portfolio.rds")
```

## Características Técnicas

### Autenticação e Headers

Todas as chamadas à API fiis.com.br requerem:

1. **User-Agent completo**: Simula Chrome 114 no macOS
2. **Cookies de sessão**: String completa de cookies (pode expirar)
3. **Nonce customizado**: `x-fiis-nonce: 61495f60b533cc40ad822e054998a3190ea9bca0d94791a1da`
4. **Headers de segurança**: `sec-ch-ua`, `sec-fetch-*`

### Formato de Dados Brasileiros

- **Números**: Separador decimal `,` e milhar `.`
- **Datas**: Formato DD/MM/YYYY
- **Data-hora**: DD/MM/YYYY HH:MM

### Tratamento de Erros

Utiliza o padrão `purrr::safely()`:
- Captura erros sem interromper o loop
- Armazena resultado em `$result` e erro em `$error`
- Permite continuar processamento mesmo com falhas individuais

### Progress Tracking

Usa `.progress = T` no `map()` para mostrar barra de progresso durante iteração sobre lista de FIIs.

## Limitações Conhecidas

1. **Cookies hardcoded**: Cookies de sessão são fixos no código e podem expirar
2. **Nonce fixo**: O nonce pode ser invalidado pelo servidor
3. **Rate limiting**: Não há controle de taxa de requisições
4. **Sem retry**: Falhas não são reprocessadas automaticamente
5. **Filtro temporal hardcoded**: Data mínima `2024-01-01` está fixa no código

## Manutenção

### Atualização de Credenciais

Quando as chamadas começarem a falhar (status 401/403), será necessário:

1. Acessar https://fiis.com.br/lupa-de-fiis/ no navegador
2. Abrir DevTools → Network
3. Capturar uma requisição à API
4. Extrair novos cookies e nonce
5. Atualizar os headers nos três arquivos de API

### Validação

Verificar se os dados foram coletados:

```r
# Verificar tamanho dos datasets
nrow(fiis)       # Deve ter ~300+ FIIs
nrow(income)     # Variável, depende do período
nrow(quotations) # Variável, depende do período

# Verificar datas recentes
max(income$data_pagamento)
max(quotations$date)
```

## Dependências

- `tidyverse` (dplyr, purrr, tidyr)
- `httr` (requisições HTTP)
- `jsonlite` (parsing JSON)
- `glue` (string templates)
- `lubridate` (manipulação de datas)
- `googlesheets4` (importação do portfolio)

## Arquivos de Saída

| Arquivo | Descrição | Origem |
|---------|-----------|--------|
| `data/portfolio.rds` | Posições da carteira | Google Sheets |
| `data/fiis.rds` | Lista completa de FIIs com indicadores | Lupa de FIIs API |
| `data/income.rds` | Histórico de proventos por ticker | FII Incomes API |
| `data/quotations.rds` | Histórico de cotações por ticker | FII Quotations API |
