library(plotly)
library(tidyverse)

port  <- readRDS("./data/portfolio.rds")

# tickers to be prospected
tickers <- c("HGBS11", "XPCM11", "HGLG11", "HGJH11", "PATC11","HGJH11", "RBED11",
             "RBDS11", "KNRE11", "BRCR11", "UBSR11", "PORD11", "FAMB11B", "BBFI11B",
             "VRTA11", "RBRD11", "BCRI11", "VGIR11", "SDIL11", "XPIN11", "XPML11", 
             "VISC11", "FVBI11", port$ticker) %>% 
  unique() %>% 
  sort()
  

# importacoes dos rendimentos
source("./R/import/proventos.R")
proventos_page <- scrapProventos(tickers)
proventos      <- extractProvFromScrap(proventos_page)

# correcao e updates
source("./R/import/fixProventos.R")
prov.fixed     <- fixProventos(proventos)
prov           <- updateProventos(prov.fixed)

# 'sharpe' de rendimentos

prov %>% 
  mutate( in_port = ticker %in% unique(port$ticker)) %>% 
  filter( ticker != "BRCR11" ) %>% 
  filter( data.pagamento >= now()-months(6) ) %>% 
  group_by(ticker, in_port) %>% 
  summarise(
    retorno = mean(rendimento),
    volat   = sd(rendimento)
  ) %>% 
  ungroup() %>% 
  ggplot() +
  geom_point(aes(x=volat, y=retorno, color=ticker, shape=in_port)) + 
  theme_minimal() -> g


ggplotly(g)

# historico de rendimentos
prov %>% 
  filter( ticker %in% tickers ) %>% 
  ggplot(aes(group=ticker)) +
  geom_line(aes(x=data.base, y=rendimento, color=ticker)) +
  theme_minimal() -> g
ggplotly(g)

# scatter
prov %>% 
  filter( ticker %in% tickers ) %>% 
  ggplot(aes(x=cota.base, y=valor, group=ticker)) +
  geom_point(aes(color=ticker, alpha=data.base)) +
  theme_minimal() -> g
ggplotly(g)


prov %>% 
  filter( ticker=="HGJH11" ) %>% 
  View()

