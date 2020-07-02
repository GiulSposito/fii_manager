capital <- port %>% 
  group_by(ticker) %>% 
  summarise(capital=sum(value)) %>% 
  ungroup()

fii_lupa <- result$data %>% 
  filter(!tipo %in% c("Tijolo: Shoppings","Tijolo: Varejo",
                      "Tijolo: Hotéis")) %>% 
  rename(ticker=codneg)

fii_prov <- fii_info %>% 
  select(ticker, proventos) %>% 
  unnest(proventos) %>% 
  group_by(ticker) %>% 
  top_n(3,data.base) %>% 
  summarise(
    valor.avg = mean(valor),
    valor.sd  = sd(valor),
    cota.base = mean(cota.base),
    rend.avg  = 100*valor.avg/cota.base
  ) %>% 
  ungroup()

fii_lprice <- fii_info %>% 
  select(price) %>% 
  unnest(price) %>% 
  group_by(ticker) %>% 
  filter(date.ref==max(date.ref)) %>% 
  rename(last.price=price.close) %>% 
  ungroup()

fii_lprice %>% 
  inner_join(fii_prov, by="ticker") %>% 
  mutate( rend.proj = 100 * valor.avg/last.price ) %>% 
  inner_join(capital, by="ticker") %>% 
  inner_join(fii_lupa, by="ticker") %>% 
  filter(cvp<=1) %>% 
  arrange(desc(rend.proj)) %>% 
  View()

capital %>% 
  filter(ticker=="MGFF11")
