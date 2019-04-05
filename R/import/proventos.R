library(tidyverse)
library(lubridate)
library(rvest)
source("./R/_draft/common.R")

.PROVENTOS_FILENAME <- "./data/fii_proventos.rds"

.processProventos <- function(pg){ 
  class(pg)
  
  # retorna uma lista vazia para as falhas
  if (is.null(pg)) return(list())
  
  # isola updates de distribuicao
  pg %>%
    html_nodes("div.entry-content ul li") %>%
    html_text() %>%
    .[grep("distribuição.*Rendimento",.)] -> dist.rend
  
  # detecta correcoes
  dist.rend %>% 
    str_detect("(Corrigiu|Correção|corrigiu|correção)") -> dist.correcao
  
  # processa valores da distribuicao
  dist.rend %>% 
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
    ) -> rendimentos
  
  rendimentos %>% 
    mutate(
      correcao = dist.correcao
    ) %>%
    distinct() %>%
    return()
}


importProventos <- function(tickers){

  url.base <- "http://fiis.com.br/"
  
  safe_read_html <- safely(read_html)
  
  tickers %>%
    unique() %>%
    paste0(url.base,.) %>% 
    map(safe_read_html) %>% 
    pluck("result") -> pages
  
  pages %>% 
    map(.processProventos) -> provs

  proventos.new <- tibble(
      ticker = unique(tickers),
      proventos = provs 
    ) %>% 
    # remove listas vazias (caso de erro de importacao)
    filter(map(proventos, length)>0) %>% 
    unnest(proventos) %>%
    arrange( ticker, desc(data.pagamento) )
  
  return(proventos.new)

}

getProventos <- function() readRDS(.PROVENTOS_FILENAME) 

