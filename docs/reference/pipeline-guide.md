# Guia de Execução do Pipeline Híbrido

## Visão Geral

O pipeline híbrido coleta dados de FIIs de múltiplas fontes, processando-os de forma incremental e validando a qualidade dos dados.

## Quick Start

### Executar Pipeline Completo

```r
# Carregar pipeline
source("R/pipeline/hybrid_pipeline.R")

# Executar todos os collectors habilitados
results <- hybrid_pipeline_run()
```

### Executar Sources Específicos

```r
# Apenas income (proventos)
results <- hybrid_pipeline_run(sources = "statusinvest_income")

# Múltiplos sources
results <- hybrid_pipeline_run(sources = c("statusinvest_income", "portfolio_googlesheets"))
```

### Modo Full Refresh

```r
# Sobrescreve dados existentes ao invés de merge incremental
results <- hybrid_pipeline_run(mode = "full_refresh")
```

## Pré-requisitos

### 1. Pacotes R

```r
# Instalar dependências
install.packages(c(
  "tidyverse", "lubridate", "httr2", "yaml",
  "rvest", "googlesheets4", "jsonlite"
))
```

### 2. Autenticação Google Sheets

```r
library(googlesheets4)
gs4_auth()  # Primeira vez, abre navegador para autenticar
```

### 3. Variáveis de Ambiente (Opcional)

Para usar o collector fiis.com.br Lupa, configure:

```bash
# Adicionar ao .Renviron
FIISCOM_COOKIE="seu_cookie"
FIISCOM_NONCE="seu_nonce"
```

**Como obter:**
1. Acessar https://fiis.com.br/lupa-de-fiis/
2. Abrir DevTools (F12) → Network
3. Procurar request para `admin-ajax.php`
4. Copiar Cookie e nonce dos headers

## Estrutura de Execução

### Ordem de Prioridade

O pipeline executa collectors nesta ordem (configurável em `config/pipeline_config.yaml`):

1. **Prioridade 1** (paralelo possível):
   - `portfolio_googlesheets` - Portfolio do Google Sheets
   - `statusinvest_income` - Proventos (batch API, **60x mais rápido**)

2. **Prioridade 2**:
   - `fiiscom_lupa` - Metadata de 538 FIIs

3. **Prioridade 3**:
   - `yahoo_prices` - Cotações históricas

4. **Prioridade 4**:
   - `statusinvest_indicators` - Indicadores fundamentalistas (scraping)

### Fallbacks Automáticos

Se um collector falhar, o pipeline tenta fallback automaticamente:

- **income**: `statusinvest_income` → `fiiscom_incomes` (API fiis.com.br)
- **quotations**: `yahoo_prices` → `fiiscom_quotations`

## Outputs

### Arquivos RDS Gerados

Todos em `data/`:

| Arquivo | Descrição | Colunas |
|---------|-----------|---------|
| `portfolio.rds` | Posições do portfólio | 7 |
| `income.rds` | Proventos históricos | 6 |
| `quotations.rds` | Cotações | 3 |
| `fiis.rds` | Metadata FIIs (Lupa) | 22 |
| `fii_indicators.rds` | **NOVO** Indicadores | 12 |

### Backups

Antes de cada save, o pipeline cria backup automático em `data_backup/`:

```
data_backup/
├── income_20260320_153045.rds
├── portfolio_20260320_153045.rds
└── ...
```

**Limpeza:** Backups >30 dias são removidos automaticamente.

### Logs

Logs estruturados em `data/.logs/`:

```
data/.logs/
└── pipeline_20260320_153045.log
```

**Formato:**
```
timestamp="2026-03-20 15:30:45" level=INFO context="hybrid_pipeline" message="Pipeline started"
timestamp="2026-03-20 15:30:46" level=INFO context="statusinvest_income" message="Collecting data"
```

## Validação

### Automática

O pipeline valida automaticamente:

1. **Schema**: Colunas e tipos corretos
2. **Qualidade**: Valores negativos, datas futuras, tickers inválidos
3. **Consistência**: Cross-source (tickers consistentes entre sources)

### Manual

```r
# Validar schemas
source("R/validators/schema_validator.R")
validate_all_rds()

# Validar qualidade
source("R/validators/data_quality_validator.R")
income <- readRDS("data/income.rds")
result <- validate_data_quality(income, "income")

# Validar consistência
source("R/validators/consistency_validator.R")
validate_consistency()
```

## Recuperação de Falhas

### Checkpoint Automático

O pipeline salva checkpoints automaticamente em `data/.checkpoints/`.

### Retomar de Checkpoint

```r
source("R/pipeline/recovery_manager.R")

# Carregar último checkpoint
checkpoint <- load_checkpoint()

# Identificar sources completados
completed <- get_completed_sources(checkpoint, config)

# Retomar (pula sources completados)
results <- hybrid_pipeline_run(sources = setdiff(all_sources, completed))
```

### Retry Manual de Sources Falhos

```r
# Identificar falhas
failed <- get_failed_sources(results)

# Retry
results_retry <- hybrid_pipeline_run(sources = failed)
```

## Performance

### Benchmarks Esperados

| Operação | Tempo Esperado |
|----------|---------------|
| Pipeline completo | <15 min |
| Income collection (464 FIIs) | <30 seg |
| Indicators collection (50 FIIs) | ~3 min |
| Portfolio import | <10 seg |
| Lupa metadata | <30 seg |

### Otimizações

1. **Executar apenas income para updates rápidos:**
   ```r
   hybrid_pipeline_run(sources = "statusinvest_income")
   ```

2. **Desabilitar indicators se não necessário** (mais lento):
   ```yaml
   # config/pipeline_config.yaml
   statusinvest_indicators:
     enabled: false
   ```

3. **Ajustar rate limiting** (cuidado com rate limits!):
   ```yaml
   statusinvest_income:
     rate_limit:
       delay_between_requests: 0.5  # Padrão: 1.0
   ```

## Troubleshooting

### Erro: "Collector file not found"

**Causa:** Collector não implementado ou arquivo movido.

**Solução:**
```r
# Verificar se arquivo existe
file.exists("R/collectors/statusinvest_income_collector.R")

# Listar collectors disponíveis
list.files("R/collectors", pattern = "collector\\.R$")
```

### Erro: "Auth expired for fiis.com.br"

**Causa:** Cookie/nonce do fiis.com.br expirou.

**Solução:**
1. Renovar credenciais (ver seção Pré-requisitos)
2. Atualizar `.Renviron`
3. Reiniciar R session: `.rs.restartR()`
4. Ou usar fallback automático (já configurado)

### Erro: "Schema validation failed"

**Causa:** Dados retornados não batem com schema esperado.

**Solução:**
```r
# Ver detalhes do erro nos logs
tail -n 50 data/.logs/pipeline_*.log

# Tentar auto-fix
source("R/validators/schema_validator.R")
data_fixed <- auto_fix_schema(data, "income")
```

### Erro: "Request failed" / "Circuit breaker open"

**Causa:** Muitas falhas consecutivas de requests HTTP.

**Solução:**
```r
# Aguardar 1 minuto (circuit breaker fecha automaticamente)
Sys.sleep(60)

# Ou resetar manualmente no código do collector
# (adicionar client$reset_circuit() se necessário)

# Retry
results <- hybrid_pipeline_run(sources = failed_sources)
```

### Performance Lenta

**Causa:** Rate limiting conservador ou muitos FIIs.

**Diagnóstico:**
```r
# Ver logs de timing
grep "duration" data/.logs/pipeline_*.log

# Ver rate limiting aplicado
grep "Rate limit" data/.logs/pipeline_*.log
```

**Solução:**
- Ajustar `delay_between_requests` no config (cuidado!)
- Desabilitar sources não críticos
- Executar indicators separadamente (mais lento)

## Configuração Avançada

### Customizar Config

Editar `config/pipeline_config.yaml`:

```yaml
data_sources:
  statusinvest_income:
    enabled: true
    priority: 1
    timeout_seconds: 30
    rate_limit:
      delay_between_requests: 1.0
    retry:
      max_attempts: 3
      backoff_factor: 2
    output: "income.rds"
    critical: true  # Para pipeline se falhar
```

### Desabilitar Validação

```yaml
execution:
  validation_enabled: false  # Não recomendado!
```

### Modo Cache

```yaml
execution:
  cache_enabled: true
  cache_dir: "data/.cache"
```

## Migração do Pipeline Antigo

### Comparar Outputs

```r
# Executar ambos
source("R/pipeline/pipeline2023.R")  # Pipeline antigo
source("R/pipeline/hybrid_pipeline.R")  # Pipeline novo

# Comparar
income_old <- readRDS("data/income_old.rds")
income_new <- readRDS("data/income.rds")

library(dplyr)
anti_join(income_old, income_new, by = c("ticker", "data_base"))
```

### Transição Gradual

1. **Semana 1-2:** Executar em paralelo, comparar
2. **Semana 3:** Corrigir discrepâncias
3. **Semana 4:** Hybrid como primário
4. **Semana 5:** Remover pipeline antigo

## Manutenção

### Limpeza Periódica

```r
# Limpar backups antigos (>30 dias)
source("R/utils/persistence.R")
clean_old_backups(keep_days = 30)

# Limpar checkpoints antigos
source("R/pipeline/recovery_manager.R")
clean_old_checkpoints(keep_days = 7)

# Limpar cache antigo
# (implementar se necessário)
```

### Monitoramento

```r
# Ver último resultado
results <- hybrid_pipeline_run()
print(results$summary)

# Ver estatísticas
results$summary$duration  # Tempo total
results$summary$success   # Número de sucessos
results$summary$failed    # Número de falhas
```

## Exemplos Completos

### Exemplo 1: Update Diário Rápido

```r
# Apenas income e portfolio (mais rápido)
source("R/pipeline/hybrid_pipeline.R")
results <- hybrid_pipeline_run(
  sources = c("portfolio_googlesheets", "statusinvest_income")
)

# ~40 segundos
```

### Exemplo 2: Update Completo Semanal

```r
# Todos os sources
results <- hybrid_pipeline_run()

# ~15 minutos
```

### Exemplo 3: Apenas Indicadores

```r
# Atualizar apenas fundamentalistas
results <- hybrid_pipeline_run(
  sources = "statusinvest_indicators"
)

# ~3-5 minutos para 50 FIIs
```

### Exemplo 4: Full Refresh com Validação

```r
# Recomeçar do zero
results <- hybrid_pipeline_run(
  mode = "full_refresh"
)

# Validar tudo
source("R/validators/schema_validator.R")
source("R/validators/consistency_validator.R")

validate_all_rds()
validate_consistency()
```

## Próximos Passos

- Ver [TROUBLESHOOTING.md](TROUBLESHOOTING.md) para problemas comuns
- Ver [AUTH_REFRESH_GUIDE.md](AUTH_REFRESH_GUIDE.md) para renovar credenciais
- Ver [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) para status do projeto
