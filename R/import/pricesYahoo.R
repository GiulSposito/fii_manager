library(BatchGetSymbols)
library(lubridate)

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
