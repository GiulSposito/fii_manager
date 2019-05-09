library(BatchGetSymbols)
library(lubridate)
library(tidyverse)

.PRICE_FILENAME = "./data/price.rds"

# get an specific git prices
getTickersPrice <- function(.tickers, .firstDate=NULL){
  
  if(is.null(.firstDate)) .firstDate=now()-years(2)
  
  .tickers %>% 
    unique() %>% 
    paste0(".SA") %>% 
    BatchGetSymbols(
      tickers = .,
      first.date = .firstDate,
      thresh.bad.data = 0.001
    ) %$%
    as_tibble(df.tickers) %>% 
    mutate(ticker = gsub(".SA","",ticker)) %>% 
    distinct() %>%
    return()
}

# update the prices of tickers
fetchTickersPrices <- function(.tickers, .firstDate=now()-years(1), 
                               .priceFilename=.PRICE_FILENAME){
  
  cotacoes <- .tickers %>%
    paste0(".SA") %>%
    c("IFIX") %>% 
    BatchGetSymbols(
      tickers = .,  #tickers
      first.date = .firstDate,
      thresh.bad.data = 0.001
    )
  
  cotacoes$df.tickers %>%
    as.tibble() %>%
    mutate(ticker = gsub(".SA","",ticker)) %>% 
    distinct() %T>% 
    saveRDS(.priceFilename) %>% 
    return()

    
}

# update the prices of portifolio tickers
updatePortfolioPrices <- function(.portfolio, 
                                  .priceFilename=.PRICE_FILENAME){
  
  tickers <- .portfolio$ticker %>% unique() 
  firstdate <- .portfolio$date %>% min()
  
  fetchTickersPrices(tickers, firstdate) %>% 
    return()
  
}

