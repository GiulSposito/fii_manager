library(BatchGetSymbols)
library(lubridate)
library(tidyverse)

getPrices <- function(.tickers, .firstDate=NULL){
  
  if(is.null(.firstDate)) .firstDate=now()-years(2)
  
  .tickers %>% 
    unique() %>% 
    paste0(".SA") %>% 
    BatchGetSymbols(
      tickers = .,
      first.date = .firstDate,
      thresh.bad.data = 0.001
    ) %>% 
    return()
}

updatePortfolioPrices <- function(){
  
  portfolio <- readRDS("./data/portfolio.rds")
  
  tickers <- portfolio$ticker %>% unique() %>% c("IFIX") %>% paste0(".SA")
  firstdate <- portfolio$date %>% min()
  
  cotacoes <- BatchGetSymbols(
    tickers = tickers,  
    first.date = firstdate,
    thresh.bad.data = 0.001
  )
  
  cotacoes$df.tickers %>%
    as.tibble() %>%
    mutate(ticker = gsub(".SA","",ticker)) %>% 
    distinct() %>% 
    saveRDS("./data/price.rds")
}

