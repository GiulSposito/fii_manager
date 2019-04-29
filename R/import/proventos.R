library(tidyverse)
library(lubridate)
library(rvest)

.PROVENTOS_FILENAME <- "./data/fii_proventos.rds"

# parse real values
.parseRealValue <- function(x) parse_number(
  gsub(pattern = "R$ *", replacement = "", x = x), 
  locale=locale(grouping_mark=".", decimal_mark=",")
)

# parse num with locale ptBR
.parseNumPtBr <- function(x) parse_number(x, locale=locale(grouping_mark=".", decimal_mark=","))

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


importProventos <- function(.tickers){

  url.base <- "http://fiis.com.br/"
  
  safe_read_html <- safely(read_html)
  
  .tickers %>%
    unique() %>%
    paste0(url.base,.) %>% 
    map(safe_read_html) %>% 
    pluck("result") -> pages

  provs <- map(pages, .processProventos)

  proventos.new <- tibble(
      ticker = unique(.tickers),
      proventos = provs 
    ) %>% 
    # remove listas vazias (caso de erro de importacao)
    filter(map(proventos, length)>0) %>% 
    unnest(proventos) %>%
    arrange( ticker, desc(data.pagamento) )
  
  return(proventos.new)

}

getProventos <- function() readRDS(.PROVENTOS_FILENAME) 

# salva ou apenda proventos
updateProventos <- function(.prov, .provFilename = .PROVENTOS_FILENAME){
  
  # verifica se o arquivo existe, se existir "apenda" se nao cria
  if(file.exists(.provFilename)){
    readRDS(.provFilename) %>% 
      bind_rows(.prov) %>% 
      distinct() %>% 
      saveRDS(.provFilename) %>% 
      return()
  } else {
    saveRDS(.prov, .provFilename)
  }
  
  # retorna o proprio arquivo
  return(.prov)
  
}

