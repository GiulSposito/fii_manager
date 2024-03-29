# draft script
library(tidyverse)
library(jsonlite)
library(httr)
library(glue)
library(lubridate)


getFIIinfo <- function(.ticker, .startDate=now()-years(1),
                       .endDate=now(), .verbose=F){
  
  print(glue("Getting {.ticker} since {.startDate}"))

  .prefix <- str_sub(.ticker, 1,4)
  
  if(.verbose) {
    verb <- verbose()
  } else {
    verb <- NULL
  } 
    
  getAPIToken <- .  %>% 
    headers() %>% 
    keep(~str_detect(.x,pattern = "XSRF-TOKEN")) %>% 
    .[[1]] %>% 
    str_extract("(.*?;)") %>% 
    str_replace(";","") %>% 
    str_replace("XSRF-TOKEN=","") %>% 
    URLdecode()
  
  set_user_agent <- add_headers("user-agent"="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36")
  
  # 
  # url_base <- "https://fiis.com.br/hgpo11"
  # resp_base <- httr::GET(url_base, verbose())
  # 
  
  # chamada para cotacao
  # é um GET
  url_cotacao <- glue("https://fiis.com.br/{.prefix}/cotacoes/?periodo=max")
  resp_cotacao <- httr::GET(url_cotacao, verb, set_user_agent)
  if (resp_cotacao$status_code!=200)
    stop(glue("Erro na chamada GET COTACAO ({httperror})"), httperror=resp_cotacao$status_code)
  
  # tratamento do retorno da cotacao
  cotacao <- resp_cotacao %>% 
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
  resp_updates <- httr::GET(url_updates, verb, set_user_agent)
  if (resp_updates$status_code!=200)
    stop(glue("Erro na chamada GET ATUALIZACOES ({httperror})"), httperror=resp_updates$status_code)
  
  api_headers <- add_headers(
    "X-Requested-With"="XMLHttpRequest",
    "Content-Type"="application/json;charset=utf-8",
    "X-XSRF-TOKEN"=  getAPIToken(resp_updates),
    "user-agent"="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36"
    
  )
  url_itens <-  "https://fiis.com.br/atualizacoes/get-items/"
  params_itens <- paste0("{\"type\":\"fund\",\"funds\":[\"",toupper(.prefix),"\"],\"startDate\":\"",format(.startDate, "%Y-%m-%d"),"\",\"endDate\":\"",format(.endDate, "%Y-%m-%d"),"\",\"content\":[]}")
  resp_items <- httr::POST(url_itens, body=params_itens, verb, api_headers)

  
  # chamada para atualizacoes
  # é um post
  # precisa dos tokens
  url_updates <- "https://fiis.com.br/atualizacoes/get-data-by-fund/"
  api_params <- paste0("{\"fund\":\"",toupper(.prefix),"\",\"startDate\":\"",format(.startDate, "%Y-%m-%d"),"\",\"endDate\":\"",format(.endDate, "%Y-%m-%d"),"\",\"content\":[]}")
  api_headers <- add_headers(
    "X-Requested-With"="XMLHttpRequest",
    "Content-Type"="application/json;charset=utf-8",
    "X-XSRF-TOKEN"=  getAPIToken(resp_items),
    "user-agent"="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36"
  )
  
  # chamada para os updates
  resp_updates <- httr::POST(
    url = url_updates, 
    verb,
    body = api_params, 
    encode = "json", 
    api_headers
  )
  
  if (resp_updates$status_code!=200)
    stop(glue("Erro na chamada POST GET-DATA-BY-FUND ({httperror})"), httperror=resp_updates$status_code)
  
  atualizacoes <- resp_updates %>% 
    content(as="text") %>% 
    fromJSON(simplifyDataFrame = T) %>% 
    as_tibble() %>% 
    set_names(c("date.time","title","link","content")) %>% 
    mutate( date.time = ymd_hms(date.time))
  
  
  return(
    tibble(
      ticker = toupper(.ticker),
      price = list(cotacao),
      # proventos = list(.convertProventos(atualizacoes)),
      updates = list(atualizacoes)
    )
  )
}

