library(rvest)
library(tidyverse)
library(lubridate)
source("./R/_draft/common.R")


.processProventos <- function(pg){ 
  pg %>%
    html_nodes("div.entry-content ul li") %>%
    html_text() %>%
    str_to_lower() %>% 
    str_subset(".*informou.*distribui.*rendimento.*") %>% 
    str_extract_all("(\\d\\d\\/\\d\\d\\/\\d+)|(\\d+\\.\\d+,\\d*)|(R\\$ \\d+,\\d*)|(\\d+,\\d*)",T) %>%
    as.tibble() -> extraction
  
  extraction %>%
    select(1:6) %>%
    set_names(c("data.update", "valor","data.pagamento",
                "data.base","cota.base","rendimento")) %>%
    mutate(
      data.update = dmy(data.update),
      valor       = .parseRealValue(valor),
      data.pagamento = dmy(data.pagamento), 
      data.base  = dmy(data.base), 
      cota.base  = .parseNumPtBr(cota.base),
      rendimento = .parseNumPtBr(rendimento)/100
    ) %>%
    distinct() %>% 
    filter(complete.cases(.)) -> rendimentos
  
  if(ncol(extraction)>6) {
    extraction %>% 
      select(1, 7, 8, 9, 5) %>% 
      set_names(c("data.update", "valor","data.pagamento",
                  "data.base","cota.base")) %>%
      mutate(
        data.update = dmy(data.update),
        valor       = .parseRealValue(valor),
        data.pagamento = dmy(data.pagamento), 
        data.base  = dmy(data.base), 
        cota.base  = .parseNumPtBr(cota.base),
        rendimento = (valor/cota.base)
      ) %>%
      distinct() %>% 
      filter(complete.cases(.)) %>%
      bind_rows(rendimentos) -> rendimentos
  }
  
  return(rendimentos)
}

.safe_processProventos <- safely(.processProventos,NA)

updateProventos <- function(){

  port <- getPortfolio()
  
  url.base <- "http://fiis.com.br/"
  
  port %>%
    select(ticker) %>%
    distinct() %>%
    mutate( inform.url = paste0(url.base,ticker) ) %>%
    mutate( html.page = inform.url %>% map(read_html) ) -> proventos.fetched
  
  proventos.fetched %>%
    mutate( proventos = html.page %>% lapply(.processProventos) ) %>% 
    select( -inform.url, -html.page ) %>%
    unnest() %>% 
    arrange( ticker, desc(data.pagamento) ) -> proventos.new
  
  saveRDS(proventos.new,"./data/proventos.rds")
  
  # if(file.exists(.PROVENTOS_FILENAME)){
  #   proventos <- readRDS(.PROVENTOS_FILENAME)
  # } else {
  #   proventos <- tibble()
  # }
  # 
  # proventos %>%
  #   bind_rows(proventos.new) %>%
  #   distinct() %T>%
  #   saveRDS(.PROVENTOS_FILENAME) %>%
  #   return()
}

getProventos <- function() readRDS(.PROVENTOS_FILENAME)