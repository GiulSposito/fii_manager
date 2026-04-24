# Troubleshooting - Pipeline Híbrido

## Problemas Comuns e Soluções

### 🔴 Erro: "Auth expired for fiis.com.br"

**Sintoma:**
```
ERROR: Auth expired for fiis.com.br
ERROR: Update env vars: FIISCOM_COOKIE, FIISCOM_NONCE
```

**Causa:** Cookie e nonce do fiis.com.br expiraram (duram ~24h).

**Solução:**

1. Abrir https://fiis.com.br/lupa-de-fiis/ no navegador
2. Abrir DevTools (F12) → Aba "Network"
3. Atualizar a página
4. Procurar request para `admin-ajax.php`
5. Clicar na request → Aba "Headers"
6. Copiar valores:
   - **Cookie**: Todo o valor do header "Cookie"
   - **Nonce**: Procurar `fd_nonce` no payload ou cookies

7. Atualizar `.Renviron`:
   ```bash
   FIISCOM_COOKIE="wordpress_logged_in_xxx=...; fd_nonce=..."
   FIISCOM_NONCE="abc123def456"
   ```

8. Reiniciar R session:
   ```r
   .rs.restartR()  # RStudio
   # ou fechar e abrir R
   ```

**Alternativa:** O pipeline usa fallback automático para cache (7 dias), então pode continuar funcionando.

---

### 🔴 Erro: "Collector file not found"

**Sintoma:**
```
ERROR: Collector file not found: R/collectors/xxx_collector.R
```

**Causa:** Collector não existe ou nome incorreto.

**Solução:**

1. Verificar collectors disponíveis:
   ```r
   list.files("R/collectors", pattern = "collector\\.R$")
   ```

2. Verificar spelling do source name em `config/pipeline_config.yaml`

3. Se collector realmente não existe, desabilitar no config:
   ```yaml
   data_sources:
     nome_do_source:
       enabled: false
   ```

---

### 🔴 Erro: "Schema validation failed"

**Sintoma:**
```
ERROR: Schema validation failed: income
ERROR:   - Column 'dy': expected numeric, got character
```

**Causa:** Dados retornados pela API mudaram de formato.

**Solução:**

1. **Ver detalhes completos:**
   ```r
   # Ler último log
   log_files <- list.files("data/.logs", full.names = TRUE)
   latest_log <- log_files[order(file.mtime(log_files), decreasing = TRUE)][1]
   readLines(latest_log, n = 100)
   ```

2. **Tentar auto-fix:**
   ```r
   source("R/validators/schema_validator.R")
   data <- readRDS("data/income.rds")
   data_fixed <- auto_fix_schema(data, "income")
   saveRDS(data_fixed, "data/income.rds")
   ```

3. **Fix manual (se auto-fix falhar):**
   ```r
   source("R/utils/brazilian_parsers.R")
   data$dy <- parse_br_number(data$dy)  # Converter para numeric
   ```

---

### 🔴 Erro: "Circuit breaker open"

**Sintoma:**
```
ERROR: Circuit breaker open until 2026-03-20 15:45:00
```

**Causa:** Muitas falhas consecutivas de HTTP requests (>5 erros).

**Solução:**

1. **Aguardar 1 minuto** (circuit breaker fecha automaticamente)

2. **Ou investigar causa raiz:**
   ```r
   # Ver logs de erros
   grep "Request failed" data/.logs/pipeline_*.log | tail -n 20
   ```

3. **Problemas comuns:**
   - Rate limit da API → Aumentar `delay_between_requests`
   - Timeout muito curto → Aumentar `timeout_seconds`
   - API temporariamente indisponível → Retry depois

---

### 🔴 Erro: "Google Sheets authentication required"

**Sintoma:**
```
ERROR: Can't get Google credentials
```

**Causa:** Não autenticado no Google Sheets.

**Solução:**

1. **Autenticar:**
   ```r
   library(googlesheets4)
   gs4_auth()  # Abre navegador
   ```

2. **Ou usar service account (produção):**
   ```r
   library(googlesheets4)
   gs4_auth(path = "service-account.json")
   ```

3. **Verificar se sheet existe:**
   ```r
   sheet_key <- "1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU"
   gs4_get(sheet_key)  # Deve retornar info do sheet
   ```

---

### ⚠️ Warning: "Data quality issues found"

**Sintoma:**
```
WARN: Data quality issues found: income (3 issues)
WARN:   - 2 negative rendimento values
WARN:   - 1 data_pagamento before data_base
```

**Causa:** Dados coletados têm problemas de qualidade (geralmente da fonte).

**Solução:**

1. **Investigar registros problemáticos:**
   ```r
   income <- readRDS("data/income.rds")

   # Valores negativos
   income[income$rendimento < 0, ]

   # Datas invertidas
   income[income$data_pagamento < income$data_base, ]
   ```

2. **Fix manual (se necessário):**
   ```r
   # Remover registros inválidos
   income_clean <- income %>%
     filter(rendimento >= 0) %>%
     filter(data_pagamento >= data_base)

   saveRDS(income_clean, "data/income.rds")
   ```

3. **Reportar problema à fonte** (Status Invest, fiis.com.br, etc.)

---

### ⚠️ Warning: "Tickers in income but not in portfolio"

**Sintoma:**
```
WARN: 5 tickers in income but not in portfolio
```

**Causa:** FIIs que pagaram proventos mas não estão no seu portfolio (normal).

**Solução:** Isto é **normal** se você não possui todos os FIIs. Para silenciar:

```yaml
# config/pipeline_config.yaml
validation:
  consistency:
    cross_source: false  # Desabilita validação cross-source
```

---

### 🐢 Performance: Pipeline muito lento

**Sintoma:** Pipeline demora >30 minutos.

**Diagnóstico:**

1. **Ver timing por source:**
   ```r
   grep "duration" data/.logs/pipeline_*.log
   ```

2. **Identificar gargalo:**
   - `statusinvest_indicators` é o mais lento (scraping)
   - `fiiscom_*` pode ser lento se auth falhar
   - `yahoo_prices` pode ser lento com muitos FIIs

**Solução:**

1. **Desabilitar indicators** (se não precisa):
   ```yaml
   statusinvest_indicators:
     enabled: false
   ```

2. **Reduzir rate limiting** (cuidado!):
   ```yaml
   statusinvest_income:
     rate_limit:
       delay_between_requests: 0.5  # Padrão: 1.0
   ```

3. **Executar apenas sources necessários:**
   ```r
   # Update rápido: apenas income
   hybrid_pipeline_run(sources = "statusinvest_income")
   ```

---

### 💾 Erro: "Failed to save RDS file"

**Sintoma:**
```
ERROR: Failed to save data/income.rds: Permission denied
```

**Causa:** Problema de permissões ou disco cheio.

**Solução:**

1. **Verificar permissões:**
   ```r
   file.access("data", 2)  # 0 = OK, -1 = sem permissão
   ```

2. **Verificar espaço em disco:**
   ```bash
   df -h .
   ```

3. **Verificar se arquivo está locked:**
   ```bash
   lsof data/income.rds  # Unix/Mac
   ```

---

### 📊 Dados faltando após execução

**Sintoma:** Pipeline executa sem erros mas dados não aparecem.

**Diagnóstico:**

1. **Verificar se collector retornou dados:**
   ```r
   results <- hybrid_pipeline_run()
   results$statusinvest_income$rows  # Deve ser > 0
   ```

2. **Verificar se arquivo foi criado:**
   ```r
   file.exists("data/income.rds")
   readRDS("data/income.rds") %>% nrow()
   ```

3. **Ver logs:**
   ```bash
   tail -n 100 data/.logs/pipeline_*.log
   ```

**Soluções comuns:**

- **Collector retornou 0 rows:** API mudou ou vazia
- **Arquivo não criado:** Erro no save (ver logs)
- **Merge removeu tudo:** Problema na deduplicação

---

### 🔄 Recovery: Retomar pipeline interrompido

**Sintoma:** Pipeline foi interrompido (Ctrl+C, crash, etc.).

**Solução:**

1. **Carregar último checkpoint:**
   ```r
   source("R/pipeline/recovery_manager.R")
   checkpoint <- load_checkpoint()
   ```

2. **Ver o que foi completado:**
   ```r
   completed <- get_completed_sources(checkpoint, config)
   print(completed)
   ```

3. **Retomar (pula completados):**
   ```r
   all_sources <- c("portfolio_googlesheets", "statusinvest_income", "fiiscom_lupa", "yahoo_prices", "statusinvest_indicators")
   remaining <- setdiff(all_sources, completed)

   results <- hybrid_pipeline_run(sources = remaining)
   ```

---

### 🧪 Testes: Como testar sem afetar dados de produção

**Solução:**

1. **Usar diretório temporário:**
   ```r
   # Backup dados atuais
   file.copy("data", "data_backup_temp", recursive = TRUE)

   # Executar pipeline
   results <- hybrid_pipeline_run()

   # Se algo der errado, restaurar
   file.remove("data/*")
   file.copy("data_backup_temp/*", "data/")
   ```

2. **Ou criar config de teste:**
   ```yaml
   # config/pipeline_config_test.yaml
   execution:
     mode: "incremental"
     backup_dir: "test_backup"
     log_dir: "test_logs"

   # Desabilitar sources críticos
   data_sources:
     portfolio_googlesheets:
       enabled: false  # Não tocar portfolio real
   ```

   ```r
   results <- hybrid_pipeline_run("config/pipeline_config_test.yaml")
   ```

---

## Debug Avançado

### Habilitar Logging DEBUG

```yaml
# config/pipeline_config.yaml
execution:
  log_level: "DEBUG"  # Padrão: INFO
```

Ou programaticamente:

```r
source("R/utils/logging.R")
logger <- create_logger(level = "DEBUG")
logger$set_level("DEBUG")
```

### Inspecionar HTTP Requests

```r
# Ver detalhes de requests/responses
source("R/utils/http_client.R")

config <- list(
  timeout_seconds = 30,
  rate_limit = list(delay_between_requests = 1.0),
  retry = list(max_attempts = 3, backoff_factor = 2)
)

client <- create_http_client(config, logger)

# Ver stats
stats <- client$stats()
print(stats)
```

### Executar Collector Individual

```r
# Isolar problema em um collector específico
source("R/collectors/statusinvest_income_collector.R")
source("R/utils/logging.R")
source("R/utils/http_client.R")

config <- yaml::read_yaml("config/pipeline_config.yaml")
logger <- create_logger(level = "DEBUG")

collector <- create_statusinvest_income_collector(
  config$data_sources$statusinvest_income,
  config,
  logger
)

data <- collector$collect()
print(head(data))
```

### Validar Manualmente

```r
# Schema
source("R/validators/schema_validator.R")
data <- readRDS("data/income.rds")
validate_schema(data, "income", strict = TRUE, logger)

# Qualidade
source("R/validators/data_quality_validator.R")
validate_data_quality(data, "income", config, logger)

# Consistência
source("R/validators/consistency_validator.R")
validate_consistency(logger = logger)
```

---

## Quando Pedir Ajuda

Se nenhuma solução acima funcionar:

1. **Coletar informações:**
   - Logs completos: `data/.logs/pipeline_*.log`
   - Versão R: `R.version.string`
   - Versões de pacotes: `sessionInfo()`
   - Config usado: `config/pipeline_config.yaml`

2. **Criar issue** (se repositório público) com:
   - Descrição do problema
   - Mensagem de erro completa
   - Passos para reproduzir
   - Informações coletadas acima

3. **Workaround temporário:**
   - Desabilitar source problemático
   - Usar dados de backup
   - Executar pipeline antigo (R/pipeline/pipeline2023.R)

---

## Checklist de Diagnóstico

Quando algo der errado, verificar em ordem:

- [ ] Logs de erro em `data/.logs/`
- [ ] Autenticação (Google Sheets, fiis.com.br)
- [ ] Conectividade com internet
- [ ] Espaço em disco disponível
- [ ] Permissões de arquivo/diretório
- [ ] Versões de pacotes atualizadas
- [ ] Config YAML válido
- [ ] Collectors existem e são loadable
- [ ] Dados de entrada válidos (se aplicável)

---

**Última atualização:** 2026-03-20
