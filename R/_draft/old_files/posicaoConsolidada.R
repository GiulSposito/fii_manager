library(tidyverse)
library(lubridate)

port <- readRDS("./data/portfolio.rds")
pric <- readRDS("./data/price.rds")
prov <- readRDS("./data/proventos.rds")


pric %>% 
  group_by(ticker) %>% 
  filter( ref.date == max(ref.date) ) %>% 
  left_join(port,., by="ticker") -> ativos

prov %>% 
  group_by(ticker) %>% 
  filter( data.pagamento == max(data.pagamento) ) %>% 
  left_join(ativos,.,by="ticker") -> last.posicao


last.posicao %>% 
  mutate( rent.prov = valor/price.close,
          rentability = (price.close - price) / price ) %>% 
  select( ticker, date, price, ref.date, price.close, cota.base, rent.prov, rentability ) %>% 
  arrange( desc(rent.prov) ) %>% 
  View()
