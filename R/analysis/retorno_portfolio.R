source("./R/import/portfolioGoogleSheets.R")
source("./R/import/pricesYahoo.R")

port <- updatePortfolio()

pric <- as.tibble(getTickersPrice(unique(port$ticker)))

pric %>% 
  filter( complete.cases(.) ) %>% 
  filter( volume!=0 ) %>% 
  group_by(ticker) %>% 
  mutate( volatil = sd(price.close) ) %>% 
  filter( ref.date == max(ref.date) ) -> last_prices

port %>% 
  group_by(ticker) %>% 
  summarise( 
    capital = sum(value),
    qtd  = sum(volume) 
  ) -> posit

posit %>% 
  inner_join(last_prices, by="ticker") %>% 
  select(ticker, capital, qtd, last.price=price.close, volatil, ref.date) %>% 
  mutate( value  = qtd*last.price,
          return = value-capital,
          tr    = return/capital ) %>% 
  ungroup() -> retornos

retornos %>% 
  ggplot(aes(x=ticker, y=value, fill=tr)) +
  geom_bar(stat="identity") +
  scale_fill_continuous(low="red", high = "green") +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45)
  )

View(retornos)

retornos %>% 
  summarise(
    capital = sum(capital),
    value   = sum(value)
  ) %>% 
  mutate( return = value-capital, 
          tr     = return/capital )
  
