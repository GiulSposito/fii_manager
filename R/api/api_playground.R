# draft script
library(tidyverse)
library(jsonlite)
library(httr)
library(glue)
library(lubridate)

.ticker <- "bbpo11"
.prefix <- str_sub(.ticker, 1,4)

getAPIToken <- .  %>% 
  headers() %>% 
  keep(~str_detect(.x,pattern = "XSRF-TOKEN")) %>% 
  .[[1]] %>% 
  str_extract("(.*?;)") %>% 
  str_replace(";","") %>% 
  str_replace("XSRF-TOKEN=","") %>% 
  URLdecode()


# 
# url_base <- "https://fiis.com.br/hgpo11"
# resp_base <- httr::GET(url_base, verbose())
# 

# chamada para cotacao
# é um GET
url_cotacao <- glue("https://fiis.com.br/{.prefix}/cotacoes/?periodo=max")
resp_cotacao <- httr::GET(url_cotacao, verbose())
resp_cotacao$status_code

# tratamento do retorno da cotacao
resp_cotacao %>% 
  content(as="text") %>% 
  fromJSON(simplifyDataFrame = T) %>% 
  .[[1]] %>% 
  as_tibble() %>% 
  set_names(c("price.close", "date.ref")) %>% 
  mutate( ticker = .ticker,
          price.close = as.numeric(price.close),
          date.ref = date(ymd_hms((date.ref))) ) %>% 
  select( ticker, date.ref, price.close )

# extraindo tockens (tá no 'set-cookie: XSRF-TOKEN'?)
url_updates <- glue("https://fiis.com.br/atualizacoes/?fii={.ticker}")
resp_updates <- httr::GET(url_updates, verbose())

api_headers <- add_headers(
  "X-Requested-With"="XMLHttpRequest",
  "Content-Type"="application/json;charset=utf-8",
  "X-XSRF-TOKEN"=  getAPIToken(resp_updates)
)
url_itens <-  "https://fiis.com.br/atualizacoes/get-items/"
params_itens <- "{\"type\":\"fund\",\"funds\":[\"mall\"],\"startDate\":\"2018-11-06\",\"endDate\":\"2019-11-06\",\"content\":[]}"
resp_items <- httr::POST(url_itens, body=params_itens, verbose(), api_headers)


# chamada para atualizacoes
# é um post
# precisa dos tokens
url_updates <- "https://fiis.com.br/atualizacoes/get-data-by-fund/"
api_params <- paste0("{\"fund\":\"",toupper(.prefix),"\",\"startDate\":\"2018-11-06\",\"endDate\":\"2019-11-06\",\"content\":[]}")
api_headers <- add_headers(
  "X-Requested-With"="XMLHttpRequest",
  "Content-Type"="application/json;charset=utf-8",
  "X-XSRF-TOKEN"=  getAPIToken(resp_items)
)


resp_updates <- httr::POST(
    url = url_updates, 
    body = api_params, 
    encode = "json", 
    api_headers, 
    verbose()
  )

resp_updates$status_code

resp_updates %>% 
  content(as="text") %>% 
  fromJSON(simplifyDataFrame = T) %>% 
  as_tibble() %>% 
  set_names(c("date.time","title","link","content")) %>% 
  mutate( date.time = ymd_hms(date.time))
