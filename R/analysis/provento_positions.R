port <- readRDS("./data/portfolio.rds")
pric <- readRDS("./data/price.rds")
prov <- readRDS("./data/fii_proventos.rds")


prov %>% 
  select(ticker, data.pagamento, valor ) %>% 
  inner_join(select(port, date, ticker, value, volume), by = "ticker") %>% 
  filter( data.pagamento >= date ) %>% 
  mutate( rend = valor*volume ) %>% 
  group_by(date, ticker, value) %>% 
  summarise(
    proventos = sum(rend),
    volatilidade = sd(rend)
  ) %>% 
  mutate(
    rendimento = proventos/value
  ) -> prov.position

prov.position %>% 
  ggplot(aes(x=volatilidade, y=rendimento, color=ticker)) +
  geom_point(aes(size=value)) + 
  theme_minimal() -> g

ggplotly(g)

prov.position %>% 
  rename(open.date=date) %>% 
  inner_join(port.position, by = c("open.date", "ticker")) %>% 
  select(open.date, ticker, position.open, proventos, rend.value) %>% 
  mutate(ret.valor = proventos+rend.value,
         ret.perc  = ret.valor/position.open) %>% 
  mutate( duracao = (open.date %--% now())/days(1) ) %>% 
  mutate( rend.mensal = ((1+ret.perc)^(1/(duracao/30)))-1 ) %>% 
  ggplot(aes(x=position.open, y=rend.mensal, color=ticker)) +
  geom_point() +
  theme_minimal() -> g

ggplotly(g)



x <- prov.position[1,]$date

now() %>% class()


%>% 
  ggplot(aes(x=open.date, y=ret.perc, color=ticker)) +
  geom_point(aes(size=position.open)) +
  geom_hline(aes(yintercept=0), color="red", linetype=2) +
  theme_minimal() -> g

ggplotly(g)
