# example_collectors_usage.R
# Example of how to use the Phase 2 collectors
# This demonstrates the standard collector pattern

library(yaml)

# Carrega dependências
source("R/utils/logging.R")
source("R/utils/http_client.R")
source("R/utils/brazilian_parsers.R")
source("R/utils/persistence.R")

source("R/collectors/collector_base.R")
source("R/collectors/portfolio_collector.R")
source("R/collectors/statusinvest_income_collector.R")

# Exemplo 1: Usando Portfolio Collector
# ------------------------------------

example_portfolio_collection <- function() {
  # Config simples
  config <- list(
    data = list(
      portfolio = list(
        google_sheet_key = "1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU"
      ),
      portfolio_file = "./data/portfolio.rds",
      backup_dir = "data_backup"
    )
  )

  # Cria logger
  logger <- create_logger(
    level = "INFO",
    context = "portfolio_example"
  )

  # Cria collector
  collector <- create_portfolio_collector(config, logger)

  # Executa coleta
  result <- collector$collect()

  # Verifica resultado
  if (result$success) {
    cat("✓ Portfolio collection successful\n")
    cat(sprintf("  - Rows collected: %d\n", result$rows))
    cat(sprintf("  - Unique tickers: %d\n", result$metadata$tickers))
    cat(sprintf("  - Portfolios: %d\n", result$metadata$portfolios))
  } else {
    cat("✗ Portfolio collection failed\n")
    cat(sprintf("  - Error: %s\n", result$error))
  }

  # Estatísticas do collector
  stats <- collector$get_stats()
  cat(sprintf("\nCollector Stats:\n"))
  cat(sprintf("  - Name: %s\n", stats$name))
  cat(sprintf("  - Run count: %d\n", stats$run_count))
  cat(sprintf("  - Last run: %s\n", stats$last_run_time))

  invisible(result)
}

# Exemplo 2: Usando Status Invest Income Collector
# ------------------------------------------------

example_income_collection <- function() {
  # Config simples
  config <- list(
    api = list(
      statusinvest = list(
        base_url = "https://statusinvest.com.br",
        earnings_endpoint = "/fii/getearnings",
        income_start_date = Sys.Date() - 365  # Último ano
      )
    ),
    data = list(
      income_file = "./data/income.rds",
      backup_dir = "data_backup"
    )
  )

  # Cria logger
  logger <- create_logger(
    level = "INFO",
    context = "income_example"
  )

  # Cria collector
  collector <- create_statusinvest_income_collector(config, logger)

  # Executa coleta
  result <- collector$collect()

  # Verifica resultado
  if (result$success) {
    cat("✓ Income collection successful\n")
    cat(sprintf("  - Rows collected: %d\n", result$rows))
    cat(sprintf("  - Date range: %s to %s\n",
                result$metadata$date_range$start,
                result$metadata$date_range$end))

    # Mostra amostra dos dados
    cat("\nSample data:\n")
    print(head(result$data, 3))
  } else {
    cat("✗ Income collection failed\n")
    cat(sprintf("  - Error: %s\n", result$error))
  }

  # Estatísticas do collector
  stats <- collector$get_stats()
  cat(sprintf("\nCollector Stats:\n"))
  cat(sprintf("  - Name: %s\n", stats$name))
  cat(sprintf("  - Run count: %d\n", stats$run_count))

  invisible(result)
}

# Exemplo 3: Carregando config de YAML
# ------------------------------------

example_with_yaml_config <- function() {
  # Carrega config (assumindo que existe config/pipeline_config.yaml)
  if (file.exists("config/pipeline_config.yaml")) {
    config <- yaml::read_yaml("config/pipeline_config.yaml")

    logger <- create_logger(
      level = config$execution$log_level,
      context = "yaml_example"
    )

    # Cria collectors
    portfolio_collector <- create_portfolio_collector(config, logger)
    income_collector <- create_statusinvest_income_collector(config, logger)

    # Executa ambos
    logger$info("Running collectors...")

    portfolio_result <- portfolio_collector$collect()
    income_result <- income_collector$collect()

    # Resumo
    logger$info("Collection complete")
    logger$info(sprintf("Portfolio: %s", ifelse(portfolio_result$success, "✓", "✗")))
    logger$info(sprintf("Income: %s", ifelse(income_result$success, "✓", "✗")))

    list(
      portfolio = portfolio_result,
      income = income_result
    )
  } else {
    cat("Config file not found: config/pipeline_config.yaml\n")
    cat("Create it using the example from the documentation\n")
  }
}

# Exemplo 4: Validando resultado
# ------------------------------

example_result_validation <- function() {
  config <- list(
    data = list(
      portfolio = list(
        google_sheet_key = "1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU"
      ),
      portfolio_file = "./data/portfolio.rds",
      backup_dir = "data_backup"
    )
  )

  logger <- create_logger(level = "INFO", context = "validation_example")

  collector <- create_portfolio_collector(config, logger)
  result <- collector$collect()

  # Valida resultado
  required_fields <- c("date", "ticker", "volume", "price", "value")
  is_valid <- validate_result(result, required_fields, logger)

  if (is_valid) {
    cat("✓ Result validation passed\n")
  } else {
    cat("✗ Result validation failed\n")
  }

  invisible(result)
}

# Para executar os exemplos:
# ---------------------------
# source("R/collectors/example_collectors_usage.R")
# example_portfolio_collection()
# example_income_collection()
# example_with_yaml_config()
# example_result_validation()
