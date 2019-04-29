library(plotly)
source("./R/import/pricesYahoo.R")

port  <- readRDS("./data/portfolio.rds")
price <- readRDS("./data/price.rds")

price <- updatePortfolioPrices()
price.v2 <- getTickersPrice( unique(port$ticker) )

htmx <- getTickersPrice("HGLG11")

htmx %>% 
  filter(complete.cases(.)) %>% 
  arrange(desc(ref.date))

price %>% 
  filter( ticker %in% unique(port$ticker) )  %>% 
  ggplot(aes(x=ref.date, y=price.close, group=ticker)) +
  geom_line(aes(color=ticker)) +
  theme_minimal() -> g

ggplotly(g)

price %>% 
  filter( ticker=="HTMX11 ")


getTickersPrice("HTMX11") -> htmlx11.price

htmlx11.price %>% filter(complete.cases(.)) %>% 
  arrange(desc(ref.date))
