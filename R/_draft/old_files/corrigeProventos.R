prices <- readRDS("./data/price.rds")
prov   <- readRDS("./data/proventos.rds")

names(prices)
names(prov)


prices %>%
  inner_join(prov, by=c("ticker"="ticker","ref.date"="data.base")) %>% 
  select(ticker, ref.date, price.close, cota.base) %>% 
  mutate( equal.prices = (round(price.close,2)==round(cota.base,2)) ) %>% 
  mutate( ratio = round(cota.base/price.close,1) ) %>% 
  filter( ratio >= 2 ) %>% 
  group_by( ticker ) %>%
  filter( ref.date == min(ref.date) ) %>%
  arrange(ticker, ref.date) %>% 
  View()

  