# pacotes ----
library(xml2)
library(rvest)
library(glue)
library(tidyverse)

# função auxiliar: parse numérico pt-BR ----
.br_locale <- locale(decimal_mark = ",", grouping_mark = ".")
parse_br_number <- function(x) {
  x %>%
    str_replace_all("\\s", " ") %>%
    str_replace_all("R\\$\\s*", "") %>%
    str_replace_all("%", "") %>%
    str_replace_all("\\u00A0", " ") %>%  # NBSP, se houver
    str_squish() %>%
    readr::parse_number(locale = .br_locale)
}
has_percent <- function(x) str_detect(x %||% "", "%")

# util: limpar título (remove ícones/ajudas) ----
clean_title <- function(x) {
  x %>%
    str_replace("\\s*help_outline.*$", "") %>%
    str_squish()
}

# extrator genérico de cards dentro de um contêiner .top-info ----
extract_cards <- function(container) {
  cards <- html_elements(container, ".info")
  tibble(
    name          = cards %>% html_element("h3.title")       %>% html_text2() %>% clean_title(),
    value_raw     = cards %>% html_element("strong.value")   %>% html_text2() %>% str_squish(),
    sub_title     = cards %>% html_element("span.sub-title") %>% html_text2() %>% str_squish(),
    sub_value_raw = cards %>% html_element("span.sub-value") %>% html_text2() %>% str_squish()
  ) %>%
    filter(!(is.na(name) & is.na(value_raw))) %>%
    mutate(
      value_num     = parse_br_number(value_raw),
      value_is_pct  = has_percent(value_raw),
      sub_value_num = parse_br_number(sub_value_raw),
      sub_is_pct    = has_percent(sub_value_raw)
    )
}

# função principal ----
get_fii_cards <- function(url_or_path) {
  doc <- read_html(url_or_path)
  
  # todos os blocos .top-info
  top_infos <- html_elements(doc, ".top-info")
  
  # 1) localizar bloco de INDICADORES (tem o card "P/VP" com h3.title)
  is_indicadores <- map_lgl(
    top_infos,
    ~ length(html_elements(.x, xpath = './/h3[contains(@class,"title")][contains(normalize-space(.), "P/VP")]')) > 0
  )
  # fallback (casos onde "P/VP" não aparece mas há "Valor em caixa" ou "CAGR")
  if (!any(is_indicadores)) {
    is_indicadores <- map_lgl(
      top_infos,
      ~ length(html_elements(.x, xpath = paste0(
        './/h3[contains(@class,"title")][contains(., "Valor em caixa") or contains(., "CAGR")]'
      ))) > 0
    )
  }
  stopifnot(any(is_indicadores))
  indicadores_box <- top_infos[which(is_indicadores)[1]]
  
  # 2) localizar bloco de COTAÇÃO (tem "Valor atual" ou "Min 52 semanas")
  is_cotacao <- map_lgl(
    top_infos,
    ~ length(html_elements(.x, xpath = paste0(
      './/h3[contains(@class,"title")][contains(., "Valor atual") or contains(., "Min 52 semanas") or contains(., "Máx 52 semanas") or contains(., "Dividend Yield") or contains(., "Valorização")]'
    ))) > 0
  )
  stopifnot(any(is_cotacao))
  cotacao_box <- top_infos[which(is_cotacao)[1]]
  
  # 3) extrair os cards de cada bloco
  indicadores <- extract_cards(indicadores_box) %>%
    mutate(area = "indicadores", .before = 1)
  
  cotacao <- extract_cards(cotacao_box) %>%
    mutate(area = "cotacao", .before = 1)
  
  # 4) retornar em um único tibble
  bind_rows(cotacao, indicadores) %>%
    # remove linhas completamente vazias (se existirem)
    filter(!(is.na(name) & is.na(value_num) & is.na(sub_value_num))) %>%
    distinct()
}

# tb <- get_fii_cards("https://statusinvest.com.br/fundos-imobiliarios/ALZR11")
# tb <- get_fii_cards("https://statusinvest.com.br/fundos-imobiliarios/HGLG11")
# print(tb)

tibble(
  ticker = c("ALZR11", "HGLG11", "kncr11")
) |> mutate( indicators = map(ticker, function(tck){
  get_fii_cards(glue("https://statusinvest.com.br/fundos-imobiliarios/{tck}"))
})) |> 
  unnest(indicators) |> 
  View()
  
  




