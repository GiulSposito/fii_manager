library(plotly)
library(tidyverse)
library(googlesheets)

port  <- readRDS("./data/portfolio.rds")

port %>% 
  group_by(ticker) %>% 
  summarise(
    capital = sum(value, na.rm=T)
  ) %>% 
  arrange(desc(capital)) %>% View()


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

# tickers <- c(sugestoes$ticker, port$ticker,"RBRF11", "MGFF11", 
#              "VGIR11", "XPLG11", "BCRI11", "HGLG11", "RBRR11",
#              "MGFF11") %>% unique()

tickers <- port$ticker %>% c("HGCR11","CPTS11B", "PATC11")  %>% unique()


# importacoes dos rendimentos
source("./R/import/proventos.R")
proventos_page <- scrapProventos(tickers)
proventos      <- extractProvFromScrap(proventos_page)

# correcao e updates
source("./R/import/fixProventos.R")
prov.fixed     <- fixProventos(proventos)
prov           <- updateProventos(prov.fixed)

saveRDS(prov, "./data/proventos.rds")

# 'sharpe' de rendimentos
# sugestoes %>%
#   select(ticker, in.portfolio) %>%
#   right_join(prov, by="ticker") %>%

port %>% 
  group_by(ticker) %>% 
  summarise(capital=sum(value)) %>% 
  right_join(prov, by = "ticker") %>% 
  filter(!(ticker=="BRCR11" & data.base==ymd(20190313))) %>% #outlier do BRCR11 
  filter( data.pagamento >= now()-months(6) ) %>% 
  group_by(ticker, capital) %>%  #, in.portfolio) %>% 
  summarise(
    retorno = mean(rendimento),
    volat   = sd(rendimento)
  ) %>% 
  ungroup() %>% 
  mutate(min.retorno = retorno - volat) %>% 
  arrange(desc(min.retorno)) %>% 
  select(-min.retorno) %>% 
  ggplot() +
  geom_point(aes(x=volat, y=retorno, color=ticker, size=capital)) + #, shape=in.portfolio)) + 
  theme_minimal() -> g

ggplotly(g)

htmlwidgets::saveWidget(as_widget(ggplotly(g)), "fii_portfolio.html")


# IPO MGFF11
# Compra do RBRF11

sel_tickers <- c("HGCR11", "HGRU11", "GTWR11", "IRDM11")

sugestoes %>% 
  filter(ticker %in% sel_tickers)

port %>% 
  group_by(ticker) %>% 
  summarise(capital=sum(value, na.rm = T)) %>% 
  arrange(capital) %>% 
  head(10) %>% 
  pull(ticker) -> sel_tickers

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

