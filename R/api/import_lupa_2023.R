# draft script
library(tidyverse)
library(jsonlite)
library(httr)
library(glue)
library(lubridate)
library(rvest)

importLupa <- function(){
  
  
  url <- 'https://fiis.com.br/wp-json/fiis/v1/lupa_fiis'
  api_headers <- add_headers(
    'authority'='fiis.com.br',
    'accept'='application/json, text/plain, */*',
    'accept-language'='pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    'cookie'='__gads=ID=ccee48ab7ca410d7:T=1689953049:RT=1689953049:S=ALNI_MbfrP5RRP6ZeAAR61MUkJEuFHAnjg; __gpi=UID=000009f8df94879b:T=1689953049:RT=1689953049:S=ALNI_Mav6boBjYOZM_MOQCxcwZwfJvv2EQ; _gcl_au=1.1.1584545622.1689953052; _gid=GA1.3.169280268.1689953052; _hjFirstSeen=1; _hjIncludedInSessionSample_1049683=0; _hjSession_1049683=eyJpZCI6IjQwMmRjODUwLTA4NmUtNDU0NS04ZWEyLTc4NmI5OTc5ZGVhOCIsImNyZWF0ZWQiOjE2ODk5NTMwNTIyNzMsImluU2FtcGxlIjpmYWxzZX0=; _hjAbsoluteSessionInProgress=0; _fbp=fb.2.1689953052408.1278115983; __hstc=109538586.a4fef3a9d6f811a4ffc7d0e16493dbe9.1689953053170.1689953053170.1689953053170.1; hubspotutk=a4fef3a9d6f811a4ffc7d0e16493dbe9; __hssrc=1; tt_c_vmt=1689953053; tt_c_c=direct; tt_c_s=direct; tt_c_m=direct; _ttuu.s=1689953053743; __qca=P0-1101259874-1689953053216; tt.u=0100007F11976F649D07EC6D02E9EA0B; tt.nprf=61,58,64,66,81,48,52,20,54,44; _hjSessionUser_1049683=eyJpZCI6ImZhNzFmNTQ4LTMyNzgtNWQ2Zi04ZTE0LTMzM2IwN2U5OGMwYyIsImNyZWF0ZWQiOjE2ODk5NTMwNTIyNjMsImV4aXN0aW5nIjp0cnVlfQ==; popup=popup-fiis.com; _ga=GA1.1.1898097372.1689953049; __hssc=109538586.3.1689953053170; _ga_NFCXE4NETS=GS1.1.1689953052.1.1.1689953955.60.0.0',
    'referer'='https://fiis.com.br/lupa-de-fiis/',
    'sec-ch-ua'='"Not.A/Brand";v="8", "Chromium";v="114", "Google Chrome";v="114"',
    'sec-ch-ua-mobile'='?0',
    'sec-ch-ua-platform'='"macOS"',
    'sec-fetch-dest'='empty',
    'sec-fetch-mode'='cors',
    'sec-fetch-site'='same-origin',
    'user-agent'='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
    'x-fiis-nonce'='61495f60b533cc40ad822e054998a3190ea9bca0d94791a1da')
  
  resp <- httr::GET(url, api_headers)
  
  fii_data <- resp |> 
    content(as="text") |> 
    fromJSON() |> 
    fromJSON() |> 
    as_tibble() |>
    mutate(negocios = str_remove_all(negocios, "."),
           across(
             c(id, post_id, last_dividend, negocios, numero_cotista),
             as.integer
           ),
           across(
             c(
               dy,
               starts_with("rendimento"),
               patrimonio_cota,
               cota_base,
               cota_vp,
               participacao_ifix,
               patrimonio
             ),
             as.numeric
           ),
           last_dividend = as.logical(last_dividend),
           across(c(data_pagamento, data_base), ymd)
    )
  
    return(fii_data)
}

importFIIList <- function(){
  read_html("https://fiis.com.br/lista-de-fundos-imobiliarios/") %>% 
    html_elements("span.ticker") %>% 
    html_text() %>% 
    str_trim() %>% 
    return()
}
