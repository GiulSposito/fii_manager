library(tidyverse)
library(lubridate)
library(plotly)

prov <- readRDS("./data/fii_proventos.rds")
pric <- readRDS("./data/price.rds")

prov %>% 
  # filter(ticker %in% c("FIIB11", "HTMX11")) %>% 
  ggplot(aes(x=data.pagamento, y=valor, group=ticker, color=ticker)) + 
  geom_line() +
  theme_minimal() -> g

ggplotly(g)

# splits 
# ( ticker=="HGLG11", data.pagamento <=ymd(20180413) )
# ( ticker=="HGRE11", data.pagamento <=ymd(20180413) )
# ( ticker=="GRLV11", data.pagamento <=ymd(20180413) )
# ( ticker=="CBOP11", data.pagamento <=ymd(20180413) )

split.tickers <- c("HGLG11","HGRE11","GRLV11","CBOP11")

prov %>%
  mutate( valor = ifelse(( ticker %in% split.tickers & data.pagamento <=ymd(20180413) ),valor/10,valor),
          cota.base = ifelse(( ticker %in% split.tickers  & data.pagamento <=ymd(20180413) ),cota.base/10,cota.base)) -> prov

saveRDS(prov, "./data/fii_proventos.rds")

