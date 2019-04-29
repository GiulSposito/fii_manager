source("./R/import/portfolioGoogleSheets.R")
port <- updatePortfolio()
prov <- readRDS("./data/fii_proventos.rds")

port %>% 
  inner_join(prov, by="ticker") %>% 
  filter( data.base >= date ) %>% 
  mutate( valor.rendimento = valor*volume ) %>% 
  group_by(date,ticker, value) %>% 
  summarise( total.rend = sum(valor.rendimento) ) %>% 
  ungroup() %>% 
  mutate(
    period     = map_dbl(date, function(x) return(interval(x,now()) %/% months(1)))
  ) %>% 
  arrange( desc(total.rend) ) -> rend

rend %>% 
  mutate( rend.perc = (total.rend/value)/(period+1) ) %>% 
  arrange( date ) %>% 
  View()



