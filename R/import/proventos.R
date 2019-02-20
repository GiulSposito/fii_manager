library(rvest)
library(tidyverse)
library(lubridate)
source("./R/_draft/common.R")

.PROVENTOS_FILENAME <- "./data/fii_proventos.rds"

.processProventos <- function(pg){ 
  class(pg)
  pg %>%
    html_nodes("div.entry-content ul li") %>%
    html_text() %>%
    .[grep("distribuição.*Rendimento",.)] %>%
    gsub("\\.","",.) %>%
    str_extract_all("(\\d\\d\\/\\d\\d\\/\\d+)|(R\\$ \\d+,\\d*)|(\\d+,\\d*)",T) %>%
    as.tibble() %>%
    select(1:6) %>% 
    set_names(c("data.update", "valor","data.pagamento",
                "data.base","cota.base","rendimento")) %>%
    mutate(
      data.update    = dmy(data.update),
      valor          = .parseRealValue(valor),
      data.pagamento = dmy(data.pagamento), 
      data.base      = dmy(data.base), 
      cota.base      = .parseRealValue(cota.base),
      rendimento     = .parseNumPtBr(rendimento)
    ) %>%
    distinct() %>%
    return()
}


updateProventos <- function(port=portfolio){

  url.base <- "http://fiis.com.br/"
  
  port %>%
    select(ticker) %>%
    distinct() %>%
    mutate( inform.url = paste0(url.base,ticker) ) %>%
    mutate( html.page = inform.url %>% map(read_html) ) -> proventos.fetched
  
  proventos.fetched %>%
    mutate( proventos = map2(ticker, html.page, function(.x,.y){
      print(.x)
      .processProventos(.y)
    })) %>%
    select( -inform.url, -html.page ) %>%
    unnest() %>%
    arrange( ticker, desc(data.pagamento) ) -> proventos.new
  
  if(file.exists(.PROVENTOS_FILENAME)){
    proventos <- readRDS(.PROVENTOS_FILENAME)
  } else {
    proventos <- tibble()
  }
  
  proventos %>%
    bind_rows(proventos.new) %>%
    distinct() %T>%
    saveRDS(.PROVENTOS_FILENAME) %>%
    return()
}

getProventos <- function() readRDS(.PROVENTOS_FILENAME)
