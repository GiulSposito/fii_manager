# draft script
library(tidyverse)
library(jsonlite)
library(httr)
library(glue)
library(lubridate)
library(rvest)

importLupa <- function(){
  getAPIToken <- .  %>% 
    headers() %>% 
    keep(~str_detect(.x,pattern = "XSRF-TOKEN")) %>% 
    .[[1]] %>% 
    str_extract("(.*?;)") %>% 
    str_replace(";","") %>% 
    str_replace("XSRF-TOKEN=","") %>% 
    URLdecode()
  
  set_user_agent <- add_headers("user-agent"="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36")

  base.url <- "https://fiis.com.br/lupa-de-fiis/"
  base.resp <- httr::GET(base.url, set_user_agent)
  base.resp$status_code
  
  data.url <- "https://fiis.com.br/lupa-de-fiis/data/"
  params <- list(filters=as.character(0:15))
  api_headers <- add_headers(
    "X-Requested-With"="XMLHttpRequest",
    "Content-Type"="application/json;charset=utf-8",
    "user-agent"="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36",
    "X-XSRF-TOKEN"=  getAPIToken(base.resp)
  )
  
  resp <- httr::POST(
    url = data.url, 
    body = toJSON(params), 
    encode = "json", 
    api_headers
  )
  
  resp$status_code
  
  data.resp <- resp %>% content("text") %>% fromJSON() 
  
  fii.coldict <- data.resp[[1]] %>% as_tibble()
  fii.data <- data.resp[[2]] %>% as_tibble()
  
  fii.data[fii.data == "N/A"] <- NA
  fii.data[fii.data == "00/00/0000"] <- NA
  
  fii.data <- fii.data %>% 
    mutate(codneg = str_remove_all(codneg, "<.+?>")) %>% 
    mutate_at(vars(iq, tipo), as.factor) %>% 
    mutate_at(vars(urenddatapag, urenddatabase), dmy) %>% 
    mutate_at(vars(urendrs, urendpercent, rendmed12rs, rendmed12percent,
                   ppc, cvp, nnegmed, ifix, ncotistas, patrimonio),
              parse_number, locale=locale(decimal_mark = ",", grouping_mark = ".")) %>% 
    mutate_at(vars(ncotistas,nnegmed), as.integer)
  
  fii.coldict$type <- sapply(fii.data, class)[1:nrow(fii.coldict)] 
  
  list(data=fii.data, dict=fii.coldict) %>% 
    return()
}

importFIIList <- function(){
  read_html("https://fiis.com.br/lista-de-fundos-imobiliarios/") %>% 
    html_elements("span.ticker") %>% 
    html_text() %>% 
    str_trim() %>% 
    return()
}
