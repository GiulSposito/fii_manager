# example_usage.R
# Exemplos de uso dos componentes da Fase 1: Fundação
# Demonstra como usar parsers, HTTP client, logger, e persistence

# ==============================================================================
# Setup
# ==============================================================================

# Carregar componentes
source("R/utils/brazilian_parsers.R")
source("R/utils/logging.R")
source("R/utils/http_client.R")
source("R/utils/persistence.R")

library(yaml)
library(dplyr)

# ==============================================================================
# 1. Parsers Brasileiros
# ==============================================================================

cat("\n=== Exemplo 1: Parsers Brasileiros ===\n\n")

# Parse números
valores_br <- c("R$ 1.234,56", "8,5%", "1.000.000,00")
valores_parsed <- parse_br_number(valores_br)
cat("Números originais:", paste(valores_br, collapse=", "), "\n")
cat("Números parsed:", paste(valores_parsed, collapse=", "), "\n\n")

# Parse datas
datas_br <- c("15/03/2026", "28-02-2026", "31.12.2025")
datas_parsed <- parse_br_date(datas_br)
cat("Datas originais:", paste(datas_br, collapse=", "), "\n")
cat("Datas parsed:", paste(datas_parsed, collapse=", "), "\n\n")

# Parse tickers
tickers <- c("alzr11", "HGLG11", "  xpml11  ")
tickers_parsed <- parse_br_ticker(tickers)
cat("Tickers originais:", paste(tickers, collapse=", "), "\n")
cat("Tickers parsed:", paste(tickers_parsed, collapse=", "), "\n\n")

# Parse percentuais
percentuais <- c("8,5%", "10%", "0,5%")
percentuais_decimal <- parse_br_percent(percentuais)
cat("Percentuais originais:", paste(percentuais, collapse=", "), "\n")
cat("Percentuais em decimal:", paste(percentuais_decimal, collapse=", "), "\n\n")

# ==============================================================================
# 2. Logging
# ==============================================================================

cat("\n=== Exemplo 2: Sistema de Logging ===\n\n")

# Criar logger
logger <- create_logger(
  level = "DEBUG",
  format = "simple",
  file_enabled = FALSE,  # Desabilitar para exemplo
  console_enabled = TRUE,
  context = "example"
)

# Diferentes níveis de log
logger$debug("Esta é uma mensagem de debug")
logger$info("Pipeline iniciado")
logger$warn("Atenção: algumas colunas têm valores faltantes")
logger$error("Erro ao conectar com API")

# Log com campos extras (formato estruturado)
logger_structured <- create_logger(
  level = "INFO",
  format = "structured",
  file_enabled = FALSE,
  console_enabled = TRUE,
  context = "collector"
)

logger_structured$info("Coletando dados", ticker="ALZR11", rows=100)

# Log de execução com tempo
cat("\nExemplo de log com tempo de execução:\n")
result <- log_execution_time(
  logger,
  function() { Sys.sleep(0.5); return(42) },
  "Operação de exemplo"
)
cat("Resultado:", result, "\n\n")

# ==============================================================================
# 3. HTTP Client
# ==============================================================================

cat("\n=== Exemplo 3: HTTP Client ===\n\n")

# Configuração de exemplo
config_http <- list(
  base_url = "https://httpbin.org",
  timeout_seconds = 10,
  rate_limit = list(delay_between_requests = 1.0),
  retry = list(max_attempts = 3, backoff_factor = 2),
  user_agent = "fiiscrapeR/2.0 Example"
)

# Criar client
client <- create_http_client(config_http, logger)

# GET request
cat("Fazendo GET request para httpbin.org/get...\n")
tryCatch({
  resp <- client$get("/get", query = list(param1 = "value1"))
  if (is_response_success(resp)) {
    cat("Sucesso! Status:", httr2::resp_status(resp), "\n")
  }
}, error = function(e) {
  cat("Erro:", e$message, "\n")
})

# Estatísticas do client
stats <- client$stats()
cat("\nEstatísticas do HTTP client:\n")
cat("  Requests:", stats$request_count, "\n")
cat("  Errors:", stats$error_count, "\n")
cat("  Circuit breaker aberto:", stats$circuit_open, "\n\n")

# ==============================================================================
# 4. Persistence
# ==============================================================================

cat("\n=== Exemplo 4: Persistence ===\n\n")

# Criar dados de exemplo
exemplo_income <- tibble(
  ticker = c("ALZR11", "HGLG11", "XPML11"),
  rendimento = c(0.95, 1.05, 0.88),
  data_base = as.Date(c("2026-03-15", "2026-03-15", "2026-03-15")),
  data_pagamento = as.Date(c("2026-03-28", "2026-03-28", "2026-03-28")),
  cota_base = c(98.50, 105.00, 92.30),
  dy = c(0.0096, 0.0100, 0.0095)
)

# Schema esperado para income.rds
income_schema <- list(
  ticker = "character",
  rendimento = "numeric",
  data_base = "Date",
  data_pagamento = "Date",
  cota_base = "numeric",
  dy = "numeric"
)

# Validar schema
cat("Validando schema do exemplo_income:\n")
is_valid <- validate_rds_schema(exemplo_income, income_schema, strict = TRUE, logger)
cat("Schema válido:", is_valid, "\n\n")

# Save com backup (arquivo temporário para exemplo)
temp_file <- tempfile(fileext = ".rds")
temp_backup <- tempdir()

cat("Salvando dados com backup...\n")
save_rds_with_backup(exemplo_income, temp_file, temp_backup, logger)

# Load
cat("Carregando dados salvos...\n")
loaded_data <- load_rds_safe(temp_file, logger = logger)
cat("Linhas carregadas:", nrow(loaded_data), "\n\n")

# Merge incremental
cat("Simulando merge incremental...\n")
novos_dados <- tibble(
  ticker = c("ALZR11", "MXRF11"),  # ALZR11 duplicado, MXRF11 novo
  rendimento = c(0.95, 1.10),
  data_base = as.Date(c("2026-03-15", "2026-03-15")),
  data_pagamento = as.Date(c("2026-03-28", "2026-03-28")),
  cota_base = c(98.50, 110.00),
  dy = c(0.0096, 0.0100)
)

merged <- merge_incremental(
  novos_dados,
  loaded_data,
  dedup_columns = c("ticker", "data_base"),
  logger
)

cat("Dados após merge:\n")
print(merged)
cat("\n")

# Limpar arquivos temporários
file.remove(temp_file)

# ==============================================================================
# 5. Configuração YAML
# ==============================================================================

cat("\n=== Exemplo 5: Carregar Configuração YAML ===\n\n")

# Carregar config
config <- yaml::read_yaml("config/pipeline_config.yaml")

# Acessar configurações
cat("Configurações de data sources:\n")
for (source_name in names(config$data_sources)) {
  source_config <- config$data_sources[[source_name]]
  cat(sprintf("  - %s: enabled=%s, priority=%d, output=%s\n",
              source_name,
              source_config$enabled,
              source_config$priority,
              source_config$output))
}

cat("\nModo de execução:", config$execution$mode, "\n")
cat("Cache habilitado:", config$execution$cache_enabled, "\n")
cat("Nível de log:", config$execution$log_level, "\n\n")

# ==============================================================================
# Resumo
# ==============================================================================

cat("\n")
cat("=" %R% 70, "\n")
cat("Resumo da Fase 1: Fundação\n")
cat("=" %R% 70, "\n\n")

cat("Os seguintes componentes foram implementados:\n\n")
cat("1. brazilian_parsers.R - Parse de números e datas brasileiras\n")
cat("   ✓ parse_br_number() - Converte 'R$ 1.234,56' → 1234.56\n")
cat("   ✓ parse_br_date() - Converte '15/03/2026' → Date\n")
cat("   ✓ parse_br_percent() - Converte '8,5%' → 0.085\n")
cat("   ✓ parse_br_ticker() - Padroniza tickers FII\n\n")

cat("2. logging.R - Sistema de logging estruturado\n")
cat("   ✓ create_logger() - Logger com níveis e contexto\n")
cat("   ✓ log_execution_time() - Log com medição de tempo\n")
cat("   ✓ Suporte a arquivo e console\n\n")

cat("3. http_client.R - HTTP client com httr2\n")
cat("   ✓ Retry automático configurável\n")
cat("   ✓ Rate limiting\n")
cat("   ✓ Circuit breaker\n")
cat("   ✓ Logging integrado\n\n")

cat("4. persistence.R - Padrões de persistência RDS\n")
cat("   ✓ save_rds_with_backup() - Backup automático\n")
cat("   ✓ merge_incremental() - Merge com deduplicação\n")
cat("   ✓ validate_rds_schema() - Validação de schema\n")
cat("   ✓ Save atômico (temp + rename)\n\n")

cat("5. pipeline_config.yaml - Configuração centralizada\n")
cat("   ✓ Data sources configuráveis\n")
cat("   ✓ Retry, rate limit, timeout por source\n")
cat("   ✓ Prioridades de execução\n\n")

cat("Próximos passos:\n")
cat("  → Fase 2: Implementar collectors (portfolio, status invest income)\n")
cat("  → Fase 3: Implementar collectors complementares\n")
cat("  → Fase 4: Orquestração (hybrid_pipeline.R)\n\n")

cat("=" %R% 70, "\n\n")

# Helper
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}
