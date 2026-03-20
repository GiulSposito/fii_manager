
fii_lupa <- readRDS("./data/fii_lupa.rds")
fii_info <- readRDS("./data/fii_info.rds")

carteira <- port %>% 
  mutate( ticker = if_else(ticker=="TEPP13", "TEPP11", ticker) ) %>% 
  mutate( ticker = if_else(ticker=="BMLC11B", "BMLC11", ticker) ) %>% 
  mutate( ticker = if_else(ticker=="BTRC11", "BTCR11", ticker) ) %>% 
  group_by(ticker) %>% 
  summarise(
    volume = sum(volume),
    capital = sum(value)
  ) %>% 
  ungroup()

fii_data <- carteira %>% 
  inner_join(fii_info) %>% 
  mutate( price.buy = capital / volume ) %>% 
  mutate( price = map(price, ~select(.x, -ticker)) ) %>% 
  unnest( price ) %>% 
  group_by( ticker ) %>% 
  filter(date.ref == max(date.ref)) %>% 
  ungroup() %>% 
  mutate( op.gain = if_else(price.close>price.buy, "gain", "loss")) %>% 
  inner_join(select(fii_lupa$data, ticker=codneg, tipo, urendrs, rendmed12rs, ppc, cvp, ncotistas, patrimonio), by="ticker"  )



fii_data %>% 
  mutate( breakeven.m = price.close/rendmed12rs,
          breakeven.y = breakeven.m/12 ) %>% 
  arrange(breakeven.y) %>% 
  View()




