# urls para obter proventos
# 
# https://statusinvest.com.br/fii/getearnings?IndiceCode=ifix&Filter=&Start=2025-09-01&End=2025-11-28
# https://statusinvest.com.br/fii/getearnings?IndiceCode=ifix&Filter=ALZR11&Start=2025-09-11&End=2025-11-28
#


library(httr2)
library(jsonlite)
library(tidyverse)
library(lubridate)

get_fii_earnings <- function(filter, start, end) {
  # Monta a URL com os parâmetros
  base_url <- "https://statusinvest.com.br/fii/getearnings"
  
  req <- request(base_url) %>%
    req_url_query(
      IndiceCode = "ifix",
      Filter = filter,
      Start = start,
      End = end
    ) %>%
    req_user_agent("Mozilla/5.0 (compatible; R HTTR2 request)") %>%  # ajuda a evitar bloqueios
    req_perform()
  
  # Extrai e parseia o conteúdo JSON
  data <- req %>% resp_body_json()
  
  # Combina as listas 'dateCom' e 'datePayment' (ou outra se quiser)
  combined <- bind_rows(data$dateCom, data$datePayment)
  
  combined |>
    select(code,
           resultAbsoluteValue,
           dateCom,
           paymentDividend,
           earningType,
           dy) |>
    purrr::set_names(c(
      "ticker",
      "dividend",
      "baseDate",
      "payDate",
      "earningType",
      "dividendYield"
    )) |>
    mutate(across(
      c(dividend, dividendYield),
      readr::parse_number,
      locale = locale(decimal_mark = ",")),
      across(
        baseDate:payDate, 
        dmy)
    ) |>
    tibble::as_tibble()
  
}

