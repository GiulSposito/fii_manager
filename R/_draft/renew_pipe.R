source("./R/api/ffis_api.R")
source("./R/import/portfolioGoogleSheets.R")

port <- updatePortfolio()

safe_getFIIInfo <- safely(.f = getFIIinfo, otherwise = list(), quiet = F)

fiis_sugestions <- tibble(
  ticker = c("HGPO11","XPLG11", "XPPR11","BTLG11","BCRI11","RBRP11","KNIP11","XPIN11",
             "VTLT11","RBBV11","BRCR11","HGPO11")
)

fiis_site <- port %>% 
  select(ticker) %>% 
  bind_rows(fiis_sugestions) %>% 
  distinct() %>% 
  arrange(ticker) %>% 
  mutate(info = map(ticker, safe_getFIIInfo))

fii_info <- fiis_site %>% 
  mutate(return_ok=map_lgl(info, function(.x) is.null(.x$error))) %>% 
  filter(return_ok) %>% 
  mutate(
    price     = map(info, ~.x$result$price),    
    proventos = map(info, ~.x$result$proventos),    
    updates   = map(info, ~.x$result$updates)    
  ) %>%
  select(ticker, price, proventos, updates)
  
saveRDS(fii_info, "./data/fii_info.rds")

last_prices <- fii_info %>% 
  select(price) %>% 
  unnest(price) %>% 
  #select(-ticker1) %>% 
  group_by(ticker) %>% 
  filter( date.ref == max(date.ref)) %>% 
  ungroup()

last_prov <- fii_info %>% 
  select(ticker, proventos) %>% 
  unnest(proventos) %>% 
  filter(data.base < ymd("2020-03-01")) %>% 
  group_by(ticker) %>% 
  top_n(3,data.base) %>% 
  summarise(
    valor = mean(valor), 
    cota.base = mean(cota.base)
  ) %>% 
  ungroup() %>% 
  mutate(rendimento=100*valor/cota.base)

fii_indicados <- last_prov %>% 
  inner_join(last_prices, by = "ticker") %>% 
  select(ticker, valor, cota.base, rendimento, date.ref, price.close) %>% 
  mutate(novo.rend = 100*valor/price.close) %>% 
  arrange(desc(novo.rend)) 

capital <- port %>% 
  group_by(ticker) %>% 
  summarise(capital=sum(value))


fii_indicados %>% 
  inner_join(capital, by="ticker") %>% 
  arrange(desc(novo.rend)) %>% 
  filter(novo.rend >= 0.7 ) 


fii_indicados %>% 
  inner_join(capital, by="ticker") %>% 
  arrange(desc(novo.rend)) %>% 
  filter(novo.rend >= 0.7 ) %>% 
  select(ticker, capital) %>% 
  inner_join(select(fii_info, ticker, proventos)) %>% 
  unnest() %>% 
  group_by(ticker) %>% 
  summarise(
    rend.avg = mean(rendimento), 
    rend.sd  = sd(rendimento),
    capital = mean(capital)
  ) %>% 
  ggplot(aes(x=rend.sd, y=rend.avg, color=ticker, label=ticker)) +
  geom_point(aes(size=capital)) +
  ggrepel::geom_text_repel() +
  theme_minimal()


