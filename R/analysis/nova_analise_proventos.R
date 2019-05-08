prov <- readRDS("./data/fii_proventos.rds")
port <- readRDS("./data/portfolio.rds")

port %>% 
  group_by(ticker) %>% 
  summarise(
    capital = sum(value)
  ) %>% 
  ungroup() -> cap.pos


prov %>% 
  filter( data.pagamento >= now()-months(12) ) %>% 
  group_by(ticker) %>% 
  summarise(
    retorno = mean(rendimento),
    volat   = sd(rendimento)
  ) %>% 
  left_join(cap.pos, by="ticker") %>% 
  mutate( capital = ifelse(is.na(capital),0,capital)) %>% 
  ggplot(aes(group=ticker)) +
  geom_point(aes(x=volat, y=retorno, color=ticker, size=capital)) + 
  theme_minimal() -> g

library(plotly)
ggplotly(g)

selec.tickers <- c( "ABCP11", "KNRI11","CBOP11", "RBRF11", "VGIR11")

prov %>% 
  filter( ticker %in% selec.tickers ) %>% 
  ggplot(aes(group=ticker)) +
  geom_line(aes(x=data.base, y=rendimento, color=ticker)) +
  theme_minimal() -> g
ggplotly(g)
