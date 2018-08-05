library(tidyverse)
library(lubridate)

portfolio <- readRDS("./data/portfolio.rds")
price     <- readRDS("./data/price.rds")

price %>%
  group_by(ticker) %>% 
  filter( ref.date == max(ref.date) ) %>%
  inner_join(portfolio, by="ticker") %>% 
  select( ticker, date, price, volume=volume.y, value, ref.date, price.close ) %>% 
  mutate( position = round(price.close * volume,2) ) %>%
  mutate( rentability = (position-value)/value ) -> position
