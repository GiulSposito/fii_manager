library(BatchGetSymbols)

selectedTickers <- c("CEOC11")

prov %>%
  filter(ticker %in% selectedTickers,
         data.pagamento >= (now()-months(12)) )  %>%
  mutate( ticker = as.factor(ticker) ) %>% 
  ggplot(aes(x=data.pagamento, y=valor, group=ticker)) +
  geom_line(aes(color=ticker), size=1) +
  theme_minimal()


prov %>%
  filter(ticker %in% selectedTickers) %>% 
  group_by(ticker) %>%
  filter( data.pagamento == max(data.pagamento) ) %>%
  arrange(desc(rendimento)) %>%
  head(10) %>% 
  pull(ticker) %>% 
  paste0(".SA") %>% 
  BatchGetSymbols(.,first.date = now()-years(1), thresh.bad.data = 0.05) -> prc

prc$df.tickers %>%
  as.tibble() %>% 
  ggplot( aes(x=ref.date, y=price.close, group=ticker )) +
  geom_line(aes(color=ticker), size=1) +
  theme_minimal()
