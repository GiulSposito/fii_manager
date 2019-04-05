port <- readRDS("./data/portfolio.rds") 
provs <- readRDS("./data/fii_proventos.rds")

provs %>% 
  group_by(ticker) %>% 
  summarise(
    valor = mean(valor),
    cota  = mean(cota.base)
  )

port$ticker %>%
  c("SDIL11","VGIR11","HGRU11","IRDM11") %>%
  importProventos() %>% 
  filter( complete.cases(.) ) -> provs

provs$ticker %>% unique()

library(plotly)

port.pos <- port %>% 
  group_by(ticker) %>% 
  summarise(
    capital = sum(value)
  )

provs %>% 
  group_by(ticker) %>% 
  filter( data.pagamento >= now()-months(6) ) %>%
  mutate(
    rend.mean = mean(rendimento),
    rend.sd   = sd(rendimento)
  ) %>% 
  ungroup() %>%
  left_join(port.pos, by="ticker") %>% 
  mutate( capital = ifelse(is.na(capital),0,capital)) %>% 
  ggplot() +
  geom_point(aes(x=rend.sd, y=rend.mean, color=ticker, size=capital)) +
  theme_minimal() -> g

ggplotly(g)

sel.tickers <-  c("FIIB11","RBRF11", "HGRU11", "VGIR11", "IRDM11")

provs %>% 
  filter( ticker %in% sel.tickers ) %>% 
  ggplot(aes(group=ticker)) +
  geom_line(aes(x=data.pagamento, y=valor, color=ticker)) +
  theme_minimal() -> g
ggplotly(g)

provs %>% 
  filter( ticker %in% sel.tickers ) %>% 
  ggplot(aes(group=ticker)) +
  geom_line(aes(x=data.base, y=cota.base, color=ticker)) +
  theme_minimal() -> g
ggplotly(g)

provs %>% 
  filter( ticker=="SDIL11" ) %>% 
  arrange(desc(data.pagamento)) %>% View()
