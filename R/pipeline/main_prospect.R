# tickers to be prospected
tickers <- c("PATC11", "HGJH11", "RBED11", "UBSR11")

## >>> RBED11 <<<


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
  filter( data.pagamento >= now()-months(24) ) %>% 
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

