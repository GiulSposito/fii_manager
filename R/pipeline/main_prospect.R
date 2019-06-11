library(plotly)
library(tidyverse)
library(googlesheets)

port  <- readRDS("./data/portfolio.rds")


# import data
gs_auth()
spreadsheet <- gs_key("1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU") %>%
  gs_read(ws=2) 

sugestoes <- spreadsheet %>%
  as_tibble() %>% 
  set_names(tolower(names(.))) %>% 
  mutate(
    in.portfolio = ticker %in% port$ticker
  )

tickers <- c(sugestoes$ticker, port$ticker,"RBRF11", "MGFF11") %>% unique()

# importacoes dos rendimentos
source("./R/import/proventos.R")
proventos_page <- scrapProventos(tickers)
proventos      <- extractProvFromScrap(proventos_page)

# correcao e updates
source("./R/import/fixProventos.R")
prov.fixed     <- fixProventos(proventos)
prov           <- updateProventos(prov.fixed)


# 'sharpe' de rendimentos
# sugestoes %>%
#   select(ticker, in.portfolio) %>%
#   right_join(prov, by="ticker") %>%
  
prov %>% 
  filter(!(ticker=="BRCR11" & data.base==ymd(20190313))) %>% #outlier do BRCR11 
  filter( data.pagamento >= now()-months(6) ) %>% 
  group_by(ticker) %>%  #, in.portfolio) %>% 
  summarise(
    retorno = mean(rendimento),
    volat   = sd(rendimento)
  ) %>% 
  ungroup() %>% 
  mutate(min.retorno = retorno - volat) %>% 
  arrange(desc(min.retorno)) %>% View()
  
  
  ggplot() +
  geom_point(aes(x=volat, y=retorno, color=ticker)) + #, shape=in.portfolio)) + 
  theme_minimal() -> g

ggplotly(g)

XP:
  RBRF11: 7000
  RBED11: 3000 
  VILG11: 4000
  
  

Easy: IPO MGFF11 - 5200


# IPO MGFF11
# Compra do RBRF11

sel_tickers <- c("RBRF11", "RBED11", "VILG11", "VGIR11", "CBOP11", "HFOF11", "CEOC11", "HGRU11")

sugestoes %>% 
  filter(ticker %in% sel_tickers)

# historico de rendimentos
prov %>% 
  filter(ticker %in% sel_tickers) %>% 
  filter( data.pagamento >= now()-months(12) ) %>% 
  filter(!(ticker=="BRCR11" & data.base==ymd(20190313))) %>% #outlier do BRCR11 
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

