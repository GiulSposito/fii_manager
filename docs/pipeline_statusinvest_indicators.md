# Pipeline Status Invest - Indicadores

## Visão Geral

Pipeline de coleta de **indicadores fundamentalistas** e **dados de cotação** de FIIs através de web scraping da página de detalhes do site **statusinvest.com.br**. Implementado no arquivo `R/_draft/statusinvest_indicators.R`.

Coleta indicadores como P/VP, dividend yield, valor patrimonial, cotação atual, e outros dados expostos na interface web.

## Arquitetura

### Fluxo

```
URL do FII (statusinvest.com.br)
      ↓
HTML Scraping (rvest)
      ↓
Parsing de cards .top-info
      ↓
Tibble estruturado
```

### Arquivo Principal

- `R/_draft/statusinvest_indicators.R`

## Estrutura da Página

### Layout HTML

A página de cada FII no Status Invest possui blocos `.top-info` que contêm cards `.info`:

```html
<div class="top-info">
  <div class="info">
    <h3 class="title">P/VP</h3>
    <strong class="value">0,95</strong>
    <span class="sub-title">Sobre P/VP</span>
    <span class="sub-value">-5,2%</span>
  </div>
  <!-- mais cards... -->
</div>
```

Existem dois blocos principais:
1. **Bloco de Indicadores** - Contém P/VP, Valor em caixa, CAGR, etc.
2. **Bloco de Cotação** - Contém Valor atual, Min/Max 52 semanas, DY, Valorização, etc.

## Componentes Principais

### 1. Função Auxiliar: `parse_br_number(x)`

Parser numérico para formato brasileiro.

**Tratamentos aplicados**:
- Remove espaços (inclusive NBSP - `\u00A0`)
- Remove prefixo `R$`
- Remove sufixo `%`
- Normaliza espaçamento
- Parse com locale brasileiro (decimal `,` e milhar `.`)

```r
parse_br_number("R$ 1.234,56")  # → 1234.56
parse_br_number("95,2%")        # → 95.2
parse_br_number("12.500")       # → 12500
```

### 2. Função Auxiliar: `clean_title(x)`

Remove ícones e elementos de ajuda dos títulos.

```r
clean_title("P/VP help_outline")  # → "P/VP"
```

### 3. Função Core: `extract_cards(container)`

Extrai todos os cards de um container `.top-info`.

**Retorna tibble com**:
- `name` - Nome do indicador (ex: "P/VP", "Valor atual")
- `value_raw` - Valor como string original
- `sub_title` - Subtítulo descritivo
- `sub_value_raw` - Subvalor como string original
- `value_num` - Valor convertido para numeric
- `value_is_pct` - Boolean indicando se é percentual
- `sub_value_num` - Subvalor convertido para numeric
- `sub_is_pct` - Boolean indicando se subvalor é percentual

### 4. Função Principal: `get_fii_cards(url_or_path)`

Coleta e estrutura todos os indicadores de um FII.

**Parâmetro**:
- `url_or_path` - URL do FII ou caminho de arquivo HTML local

**Retorna**: Tibble com todos os cards organizados por área (cotacao, indicadores)

## Lógica de Identificação de Blocos

### Bloco de Indicadores

Identificado pela presença do card "P/VP":

```r
xpath = './/h3[contains(@class,"title")][contains(normalize-space(.), "P/VP")]'
```

**Fallback**: Se "P/VP" não for encontrado, busca por "Valor em caixa" ou "CAGR"

### Bloco de Cotação

Identificado pela presença de qualquer um destes cards:
- "Valor atual"
- "Min 52 semanas"
- "Máx 52 semanas"
- "Dividend Yield"
- "Valorização"

```r
xpath = './/h3[contains(@class,"title")][contains(., "Valor atual") or
         contains(., "Min 52 semanas") or ...]'
```

## Estrutura de Dados

### Tibble Resultante

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `area` | string | "cotacao" ou "indicadores" |
| `name` | string | Nome do indicador |
| `value_raw` | string | Valor original (texto) |
| `sub_title` | string | Subtítulo explicativo |
| `sub_value_raw` | string | Subvalor original (texto) |
| `value_num` | numeric | Valor numérico principal |
| `value_is_pct` | boolean | Indica se valor é percentual |
| `sub_value_num` | numeric | Subvalor numérico |
| `sub_is_pct` | boolean | Indica se subvalor é percentual |

### Exemplo de Saída

```r
# A tibble: 12 × 9
  area      name           value_raw  sub_title       sub_value_raw value_num value_is_pct sub_value_num sub_is_pct
  <chr>     <chr>          <chr>      <chr>           <chr>             <dbl> <lgl>                <dbl> <lgl>
1 cotacao   Valor atual    R$ 102,50  Fechamento      -                 102.5 FALSE                   NA NA
2 cotacao   Min 52 semanas R$ 95,20   Mínima do ano   -                  95.2 FALSE                   NA NA
3 cotacao   Máx 52 semanas R$ 108,90  Máxima do ano   -                 108.9 FALSE                   NA NA
4 cotacao   Dividend Yield 8,5%       Último ano      -                   8.5 TRUE                    NA NA
5 indicadores P/VP         0,95       Preço/Valor P.  -5,2%               0.95 FALSE               -5.2 TRUE
6 indicadores Valor em caixa R$ 1.250 Por cota        -              1250    FALSE                   NA NA
...
```

## Indicadores Típicos Coletados

### Área: Cotação

- **Valor atual** - Cotação de fechamento atual
- **Mínima 52 semanas** - Menor cotação no último ano
- **Máxima 52 semanas** - Maior cotação no último ano
- **Dividend Yield** - DY acumulado (geralmente 12 meses)
- **Valorização (12m)** - Valorização percentual no período

### Área: Indicadores

- **P/VP** - Preço sobre Valor Patrimonial
- **Valor Patrimonial** - VP por cota
- **Valor em caixa** - Caixa disponível
- **Liquidez** - Liquidez média diária
- **Vacância** - Taxa de vacância
- **CAGR** - Taxa de crescimento anual composta
- **Dividend Yield médio** - DY médio histórico
- **Número de cotistas**
- **Patrimônio líquido**

> **Nota**: Os indicadores disponíveis variam por tipo de FII (tijolo, papel, híbrido, etc.)

## Exemplo de Uso

### Uso Básico

```r
source("R/_draft/statusinvest_indicators.R")

# Coletar indicadores de um FII
indicators_alzr <- get_fii_cards("https://statusinvest.com.br/fundos-imobiliarios/ALZR11")

# Visualizar
print(indicators_alzr)
View(indicators_alzr)
```

### Uso em Batch

```r
library(tidyverse)
library(glue)

# Lista de FIIs
fiis_para_coletar <- tibble(
  ticker = c("ALZR11", "HGLG11", "KNCR11", "VISC11")
)

# Coletar indicadores de todos
indicators_all <- fiis_para_coletar %>%
  mutate(
    url = glue("https://statusinvest.com.br/fundos-imobiliarios/{ticker}"),
    indicators = map(url, get_fii_cards)
  ) %>%
  unnest(indicators)

# Visualizar
View(indicators_all)

# Salvar
saveRDS(indicators_all, "data/fii_indicators.rds")
```

### Filtrar Indicadores Específicos

```r
# Apenas P/VP e Dividend Yield
pvp_dy <- indicators_all %>%
  filter(name %in% c("P/VP", "Dividend Yield")) %>%
  select(ticker, name, value_num, value_is_pct)

# Apenas área de cotação
cotacoes <- indicators_all %>%
  filter(area == "cotacao")

# Apenas área de indicadores fundamentalistas
fundamentos <- indicators_all %>%
  filter(area == "indicadores")
```

## Formato Wide (Pivot)

Para análise, pode ser útil pivotear para formato wide:

```r
indicators_wide <- indicators_all %>%
  select(ticker, name, value_num) %>%
  pivot_wider(
    names_from = name,
    values_from = value_num
  )

# Resultado:
# ticker P/VP Dividend_Yield Valor_atual ...
# ALZR11 0.95 8.5           102.5       ...
# HGLG11 1.02 7.8           98.2        ...
```

## Robustez

### Tratamento de Variações

A função utiliza estratégias defensivas:

1. **Múltiplos XPath**: Fallback se indicador esperado não existir
2. **Distinct final**: Remove duplicatas se houver
3. **Stopifnot**: Garante que pelo menos um bloco foi encontrado
4. **Normalização de espaços**: `str_squish()` em todos os textos

### Casos de Erro

```r
# Usar safely() para robustez
safe_get_cards <- purrr::safely(get_fii_cards)

result <- safe_get_cards("https://statusinvest.com.br/fundos-imobiliarios/INVALID11")

if(!is.null(result$error)) {
  message("Erro ao coletar: ", result$error$message)
}
```

## Comparação com Pipeline Antigo

| Aspecto | Status Invest Indicators | fiis.com.br API |
|---------|-------------------------|-----------------|
| **Fonte** | Web scraping HTML | API REST |
| **Dados** | Indicadores + Cotação | Cotação histórica detalhada |
| **Granularidade temporal** | Snapshot (ponto no tempo) | Série histórica |
| **Autenticação** | ❌ Não requer | ❌ Requer cookies+nonce |
| **Estabilidade** | ⚠️ Frágil (HTML pode mudar) | ✅ API estruturada |
| **Indicadores fundamentalistas** | ✅ P/VP, VP, vacância, etc. | ❌ Não disponível |
| **Histórico de cotações** | ❌ Apenas valor atual | ✅ Histórico completo |
| **Performance** | ⚠️ Mais lento (HTML parsing) | ✅ Mais rápido (JSON) |

## Boas Práticas

### 1. Rate Limiting

```r
# Adicionar delay entre requests
map(ticker_list, function(ticker) {
  url <- glue("https://statusinvest.com.br/fundos-imobiliarios/{ticker}")
  result <- get_fii_cards(url)
  Sys.sleep(2)  # 2 segundos entre requests
  result
})
```

### 2. Cache Local

```r
# Salvar HTML local para desenvolvimento/debug
library(rvest)

url <- "https://statusinvest.com.br/fundos-imobiliarios/ALZR11"
html <- read_html(url)
write_html(html, "temp/alzr11.html")

# Depois usar arquivo local
indicators <- get_fii_cards("temp/alzr11.html")
```

### 3. User Agent

Adicionar user-agent customizado se necessário:

```r
library(httr)

url <- "https://statusinvest.com.br/fundos-imobiliarios/ALZR11"
response <- GET(url, user_agent("Mozilla/5.0..."))
content <- content(response, as = "text")
html <- read_html(content)

# Continuar com parsing...
```

### 4. Validação de Estrutura

```r
# Verificar se estrutura esperada existe
validate_structure <- function(url) {
  html <- read_html(url)
  top_infos <- html_elements(html, ".top-info")

  if(length(top_infos) == 0) {
    stop("Estrutura HTML mudou: .top-info não encontrado")
  }

  invisible(TRUE)
}
```

## Limitações Conhecidas

1. **Fragilidade**: Mudanças no HTML quebram o scraping
2. **Snapshot**: Apenas valores atuais, sem histórico
3. **Sem API oficial**: Depende de estrutura HTML não documentada
4. **Variabilidade**: Indicadores disponíveis variam por tipo de FII
5. **Rate limits**: Possível bloqueio se muitas requisições rápidas
6. **Performance**: Mais lento que APIs REST (parsing HTML)

## Manutenção

### Quando o Scraping Quebrar

1. Inspecionar HTML atual da página
2. Verificar se classes `.top-info` e `.info` ainda existem
3. Verificar estrutura dos cards (h3.title, strong.value, etc.)
4. Atualizar XPath queries se necessário
5. Testar com múltiplos FIIs diferentes

### Monitoramento

```r
# Script de validação
validate_scraping <- function() {
  test_tickers <- c("ALZR11", "HGLG11")

  results <- map(test_tickers, function(ticker) {
    url <- glue("https://statusinvest.com.br/fundos-imobiliarios/{ticker}")
    tryCatch({
      get_fii_cards(url)
      TRUE
    }, error = function(e) {
      message("FALHA: ", ticker, " - ", e$message)
      FALSE
    })
  })

  all(unlist(results))
}
```

## Dependências

- `xml2` - Parser XML/HTML
- `rvest` - Web scraping
- `glue` - String templates
- `tidyverse` - Manipulação de dados (dplyr, stringr, purrr)

## Status

⚠️ **DRAFT** - Este pipeline está em `R/_draft/` e ainda não está integrado ao pipeline principal.

### Próximos Passos

1. Criar função de cache para evitar re-scraping
2. Implementar retry logic para requisições falhadas
3. Adicionar validação de estrutura HTML
4. Criar scheduling para coleta periódica
5. Integrar com pipeline principal ou criar novo pipeline consolidado
6. Avaliar se vale manter ou migrar para API quando/se disponível

## Uso Combinado com Pipeline de Proventos

```r
# Pipeline completo Status Invest
source("R/_draft/statusinvest_proventos.R")
source("R/_draft/statusinvest_indicators.R")

# Tickers da carteira
portfolio <- readRDS("data/portfolio.rds")
tickers <- unique(portfolio$ticker)

# 1. Coletar proventos (API)
proventos <- get_fii_earnings("", "2024-01-01", "2025-03-20") %>%
  filter(ticker %in% tickers)

# 2. Coletar indicadores (Scraping)
indicators <- tibble(ticker = tickers) %>%
  mutate(
    url = glue("https://statusinvest.com.br/fundos-imobiliarios/{ticker}"),
    indicators = map(url, possibly(get_fii_cards, NULL))
  ) %>%
  unnest(indicators)

# 3. Salvar
saveRDS(proventos, "data/income.rds")
saveRDS(indicators, "data/fii_indicators.rds")

# 4. Join para análise
fii_complete <- proventos %>%
  left_join(
    indicators %>% filter(name == "P/VP") %>% select(ticker, pvp = value_num),
    by = "ticker"
  )
```
