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
  ## print(class(pg))
  
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

# faz o scrapping e tratamento dos proventos
# tirados do site www.fiis.com.br
importProventos <- function(.tickers, .url_base = "http://fiis.com.br/"){

  # funcao para fazer o "fetch" da pagina
  # de maneira segura (sem falhar)
  safe_read_html <- possibly(read_html, otherwise = list())
  safe_process   <- possibly(.processProventos, otherwise = list())
  
  # ira montar um tibble com os tickers para scrapear e tratar
  tibble( ticker = unique(.tickers) ) %>% 
    mutate( url = paste0(.url_base,ticker) ) %>% 
    mutate( page = map(url, safe_read_html)) -> tickers_page
  
  tickers_page %>% 
    filter( map(page, length)>0 ) %>% 
    mutate( proventos = map(page, .processProventos) ) %>% 
    filter( map(proventos, length)>0 ) %>% 
    select( -url, -page ) %>% 
    unnest( proventos ) %>% 
    arrange( ticker, desc(data.pagamento) ) %>% 
    return()
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

