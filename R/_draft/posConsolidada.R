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

sum(position$value)  
sum(position$position)

(sum(position$position) - sum(position$value))  / sum(position$value)

(sum(position$position) - sum(position$value)) / rendMes


rendMes <- 9.74+8.91+20.10+7.56+11.04+18.00+15.00+15.00+16.00+8.54+16.12+14.1+8.10+12+2+10.71+8.95+8.05+12.83+28.86+43.50+10.8+8.69+9.1

rendMes/sum(position$value)
rendMes/sum(position$position)

5664