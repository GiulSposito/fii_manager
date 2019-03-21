port <- readRDS("./data/portfolio.rds")
pric <- readRDS("./data/price.rds")
prov <- readRDS("./data/fii_proventos.rds")

pric %>% 
  group_by(ticker) %>% 
  filter(ref.date==max(ref.date)) %>% 
  ungroup() %>% 
  select(ticker, ref.date, price.close) -> last.prices

# valor do portfolio atual
port %>% 
  inner_join(last.prices, by = "ticker") %>% 
  mutate( price.open = (value+taxes)/volume ) %>% 
  mutate( position.open = price.open * volume, 
          position.close = price.close * volume ) %>% 
  select( ticker, open.date = date, close.date=ref.date, volume, 
          price.open, price.close, position.open, position.close) %>% 
  mutate( rend.value = position.close - position.open,
          rend.perc  = rend.value/position.open ) -> port.position

# valor contra abertura da operacao
library(ggrepel)
port.position %>% 
  ggplot(aes(open.date, rend.value)) +
  geom_hline(aes(yintercept=0), linetype=2, color="red") +
  geom_point(aes(color=ticker, size=position.close)) +
  geom_label_repel(aes(label=ticker,color=ticker),size=2) +
  theme_minimal()


