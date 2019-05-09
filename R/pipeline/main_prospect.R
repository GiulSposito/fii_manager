# tickers to be prospected
tickers <- c("PATC11", "HGJH11", "RBED11", "UBSR11")

source("./R/import/pricesYahoo.R")         
price <- fetchTickersPrices(tickers)

source("./R/import/proventos.R")
proventos_page <- scrapProventos(tickers)
proventos      <- extractProvFromScrap(proventos_page)

source("./R/import/fixProventos.R")
prov.fixed     <- fixProventos(proventos)
prov           <- updateProventos(prov.fixed)

prov %>% 
  filter( data.pagamento >= now()-months(3) ) %>% 
  group_by(ticker) %>% 
  summarise(
    retorno = mean(rendimento),
    volat   = sd(rendimento)
  ) %>% 
  ggplot(aes(group=ticker)) +
  geom_point(aes(x=volat, y=retorno, color=ticker)) + 
  theme_minimal() -> g

library(plotly)
ggplotly(g)
