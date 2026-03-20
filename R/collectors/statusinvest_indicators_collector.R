# statusinvest_indicators_collector.R
# Coletor para Status Invest indicators via web scraping
# Extrai indicadores fundamentalistas: P/VP, vacância, DY, etc.

library(rvest)
library(dplyr)
library(purrr)
library(stringr)
library(glue)
library(tidyr)

source("R/utils/logging.R")
source("R/utils/brazilian_parsers.R")
source("R/utils/persistence.R")
source("R/collectors/collector_base.R")

#' Create Status Invest Indicators Collector
#'
#' @param config List with configuration
#' @param logger Logger instance
#' @return Collector instance
#' @export
create_statusinvest_indicators_collector <- function(config, logger) {
  collect_fn <- function(config, logger) {
    # Get portfolio tickers
    portfolio_file <- config$data$portfolio_file %||% "./data/portfolio.rds"
    if (!file.exists(portfolio_file)) {
      return(list(success = FALSE, error = "Portfolio file not found"))
    }
    portfolio <- readRDS(portfolio_file)
    tickers <- unique(portfolio$ticker)

    collect_statusinvest_indicators(tickers = tickers, config = config, logger = logger)
  }

  create_base_collector(
    name = "statusinvest_indicators",
    config = config,
    logger = logger,
    collect_fn = collect_fn
  )
}

#' Coalesce NULL Helper
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Collect Status Invest Indicators for FIIs
#'
#' Scrapes fundamental indicators from Status Invest pages.
#' Returns NEW schema for fii_indicators.rds with comprehensive metrics.
#' Implements rate limiting (3s between requests) for respectful scraping.
#'
#' @param tickers Character vector of FII tickers
#' @param config List with collector configuration
#' @param logger Logger instance (optional)
#' @return List with success, data, metadata, and error (if any)
#' @export
collect_statusinvest_indicators <- function(tickers, config, logger = NULL) {
  start_time <- Sys.time()

  if (!is.null(logger)) {
    logger$info(glue("Starting Status Invest indicators collection for {length(tickers)} tickers"))
  }

  result <- list(
    success = FALSE,
    data = NULL,
    metadata = list(
      source = "statusinvest_indicators",
      collected_at = Sys.time(),
      tickers_total = length(tickers),
      tickers_success = 0,
      tickers_failed = 0,
      rows = 0
    ),
    error = NULL
  )

  tryCatch({
    # Rate limiting config
    delay_seconds <- config$rate_limit$delay_between_requests

    # Collect indicators para cada ticker
    all_indicators <- list()
    failed_tickers <- character(0)

    for (i in seq_along(tickers)) {
      ticker <- tickers[i]

      if (!is.null(logger)) {
        logger$info(glue("Collecting {ticker} ({i}/{length(tickers)})"))
      }

      # Scrape indicators
      ticker_data <- tryCatch({
        scrape_fii_indicators(ticker, config$base_url, logger)
      }, error = function(e) {
        if (!is.null(logger)) {
          logger$warn(glue("Failed to scrape {ticker}: {e$message}"))
        }
        failed_tickers <<- c(failed_tickers, ticker)
        NULL
      })

      if (!is.null(ticker_data)) {
        all_indicators[[ticker]] <- ticker_data
      }

      # Rate limiting: sleep entre requests (exceto no último)
      if (i < length(tickers)) {
        if (!is.null(logger)) {
          logger$debug(glue("Rate limit: sleeping {delay_seconds}s"))
        }
        Sys.sleep(delay_seconds)
      }
    }

    # Combina resultados
    if (length(all_indicators) == 0) {
      stop("No indicators collected successfully")
    }

    indicators_df <- bind_rows(all_indicators) %>%
      mutate(collected_at = Sys.time())

    if (!is.null(logger)) {
      logger$info(glue("Collected indicators for {nrow(indicators_df)} tickers ({length(failed_tickers)} failed)"))
    }

    # Merge com dados existentes (incremental)
    output_path <- file.path("data", config$output)
    existing <- load_rds_safe(output_path, default = NULL, logger = logger)

    if (!is.null(existing)) {
      # Remove entradas antigas dos mesmos tickers para atualizar
      existing_filtered <- existing %>%
        filter(!ticker %in% indicators_df$ticker)

      indicators_final <- bind_rows(existing_filtered, indicators_df) %>%
        distinct()

      if (!is.null(logger)) {
        logger$info(glue("Merged with existing: {nrow(existing)} old + {nrow(indicators_df)} new = {nrow(indicators_final)} total"))
      }
    } else {
      indicators_final <- indicators_df
    }

    # Salvar com backup
    save_rds_with_backup(
      indicators_final,
      output_path,
      backup_dir = "data_backup",
      logger = logger
    )

    # Resultado final
    result$success <- TRUE
    result$data <- indicators_final
    result$metadata$tickers_success <- nrow(indicators_df)
    result$metadata$tickers_failed <- length(failed_tickers)
    result$metadata$rows <- nrow(indicators_final)
    result$metadata$duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    result$metadata$failed_tickers <- failed_tickers

    if (!is.null(logger)) {
      logger$info(glue("Collection completed in {round(result$metadata$duration_secs, 2)}s"))
    }

    result

  }, error = function(e) {
    if (!is.null(logger)) {
      logger$error(glue("Collection failed: {e$message}"))
    }

    result$error <- e$message
    result$metadata$duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    result
  })
}

#' Scrape FII Indicators from Status Invest Page
#'
#' Extracts indicators from both "cotacao" and "indicadores" sections.
#' Based on reference code from R/_draft/statusinvest_indicators.R
#'
#' @param ticker Character, FII ticker (e.g., "ALZR11")
#' @param base_url Character, base URL for Status Invest
#' @param logger Logger instance (optional)
#' @return Tibble with one row containing all indicators
#' @keywords internal
scrape_fii_indicators <- function(ticker, base_url, logger = NULL) {
  url <- glue("{base_url}/{ticker}")

  if (!is.null(logger)) {
    logger$debug(glue("Scraping {url}"))
  }

  # Lê página
  doc <- read_html(url)

  # Extrai todos os blocos .top-info
  top_infos <- html_elements(doc, ".top-info")

  # 1) Localiza bloco de COTAÇÃO
  is_cotacao <- map_lgl(
    top_infos,
    ~ length(html_elements(.x, xpath = paste0(
      './/h3[contains(@class,"title")][contains(., "Valor atual") or ',
      'contains(., "Min 52 semanas") or contains(., "Máx 52 semanas") or ',
      'contains(., "Dividend Yield") or contains(., "Valorização")]'
    ))) > 0
  )

  # 2) Localiza bloco de INDICADORES
  is_indicadores <- map_lgl(
    top_infos,
    ~ length(html_elements(.x, xpath = paste0(
      './/h3[contains(@class,"title")][contains(normalize-space(.), "P/VP")]'
    ))) > 0
  )

  # Fallback para indicadores (se P/VP não aparece)
  if (!any(is_indicadores)) {
    is_indicadores <- map_lgl(
      top_infos,
      ~ length(html_elements(.x, xpath = paste0(
        './/h3[contains(@class,"title")][contains(., "Valor em caixa") or contains(., "CAGR")]'
      ))) > 0
    )
  }

  # Extrai cards
  cotacao_cards <- NULL
  indicadores_cards <- NULL

  if (any(is_cotacao)) {
    cotacao_box <- top_infos[which(is_cotacao)[1]]
    cotacao_cards <- extract_status_cards(cotacao_box, "cotacao")
  }

  if (any(is_indicadores)) {
    indicadores_box <- top_infos[which(is_indicadores)[1]]
    indicadores_cards <- extract_status_cards(indicadores_box, "indicadores")
  }

  # Combina cards
  all_cards <- bind_rows(cotacao_cards, indicadores_cards)

  if (nrow(all_cards) == 0) {
    stop(glue("No cards found for {ticker}"))
  }

  # Transforma em formato wide (uma linha por ticker)
  indicators_wide <- all_cards %>%
    select(name, value_num) %>%
    distinct() %>%
    # Normaliza nomes de colunas
    mutate(
      name = str_to_lower(name) %>%
        str_replace_all("\\s+", "_") %>%
        str_remove_all("[^a-z0-9_]") %>%
        str_replace("p/vp", "p_vp") %>%
        str_replace("dividend_yield", "dy") %>%
        str_replace("valorizao", "valorizacao") %>%
        str_replace("mnimo", "min") %>%
        str_replace("mximo", "max") %>%
        str_replace("nmero", "numero")
    ) %>%
    pivot_wider(
      names_from = name,
      values_from = value_num,
      values_fill = NA_real_
    ) %>%
    mutate(ticker = ticker, .before = 1)

  # Padroniza nomes de colunas para schema esperado
  indicators_wide <- indicators_wide %>%
    rename_with(
      ~ case_when(
        . == "valor_atual" ~ "valor_atual",
        . == "min_52_semanas" ~ "min_52sem",
        . == "max_52_semanas" ~ "max_52sem",
        . == "dy" ~ "dividend_yield",
        . == "valorizacao_12m" ~ "valorizacao_12m",
        . == "p_vp" ~ "p_vp",
        . == "valor_patrimonial" ~ "valor_patrimonial",
        . == "vacancia" ~ "vacancia",
        . == "valor_em_caixa" ~ "valor_caixa",
        . == "liquidez_diaria" ~ "liquidez",
        . == "numero_de_cotistas" ~ "numero_cotistas",
        TRUE ~ .
      ),
      .cols = everything()
    )

  indicators_wide
}

#' Extract Cards from Status Invest Container
#'
#' @param container rvest node
#' @param area Character, "cotacao" or "indicadores"
#' @return Tibble with card data
#' @keywords internal
extract_status_cards <- function(container, area) {
  cards <- html_elements(container, ".info")

  tibble(
    area = area,
    name = cards %>% html_element("h3.title") %>% html_text2() %>% clean_title_text(),
    value_raw = cards %>% html_element("strong.value") %>% html_text2() %>% str_squish(),
    sub_title = cards %>% html_element("span.sub-title") %>% html_text2() %>% str_squish(),
    sub_value_raw = cards %>% html_element("span.sub-value") %>% html_text2() %>% str_squish()
  ) %>%
    filter(!(is.na(name) & is.na(value_raw))) %>%
    mutate(
      value_num = parse_br_number(value_raw),
      value_is_pct = is_br_percent(value_raw),
      sub_value_num = parse_br_number(sub_value_raw),
      sub_is_pct = is_br_percent(sub_value_raw)
    )
}

#' Clean Title Text
#'
#' Removes help icons and extra whitespace from titles
#'
#' @param x Character vector
#' @return Character vector (cleaned)
#' @keywords internal
clean_title_text <- function(x) {
  x %>%
    str_replace("\\s*help_outline.*$", "") %>%
    str_squish()
}

#' Validate Indicators Schema
#'
#' @param data Tibble with indicators data
#' @param logger Logger instance (optional)
#' @return Logical, TRUE if valid
#' @keywords internal
validate_indicators_schema <- function(data, logger = NULL) {
  required_cols <- c("ticker", "collected_at")

  missing <- setdiff(required_cols, names(data))

  if (length(missing) > 0) {
    if (!is.null(logger)) {
      logger$error(glue("Missing required columns: {paste(missing, collapse=', ')}"))
    }
    return(FALSE)
  }

  # Verifica se tem pelo menos alguns indicadores
  indicator_cols <- setdiff(names(data), c("ticker", "collected_at"))

  if (length(indicator_cols) == 0) {
    if (!is.null(logger)) {
      logger$error("No indicator columns found")
    }
    return(FALSE)
  }

  TRUE
}
