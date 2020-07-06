fii_lupa$data$tipo %>% 
  unique()



sel_tickers <- fii_lupa$data %>% 
  filter(tipo=="Tijolo: Escritórios") %>% 
  pull(codneg)


fii_info %>% 
  filter(ticker!="FAMB11B") %>% 
  select(price) %>% 
  unnest(price) %>% 
  filter(date.ref>=now()-months(3)) %>% 
  group_by(ticker) %>% 
  nest() %>% 
  mutate( model  = map(data,~lm(price.close~date.ref, data=.x)),
          glance = map(model, glance),
          coefs  = map(model, tidy),
          alpha  = map(coefs, ~filter(.x, term=="date.ref"))) %>% 
  unnest(glance) %>% 
  select(ticker, r.squared, alpha) %>% 
  unnest(alpha) %>% 
  select(ticker, estimate, r.squared) %>% View()
  ggplot(aes(x=r.squared, y=estimate, color=estimate>0)) +
  geom_point() +
  geom_text_repel(aes(label=ticker)) +
  theme_light() +
  theme( legend.position="none")
  
  fii_lupa$data %>% 
    select(ticker=codneg, ppc) %>% 
    inner_join(fii_info) %>% 
    select(price, ppc) %>% 
    unnest(price) %>% 
    filter(date.ref >= now()-years(1)) %>% 
    ggplot(aes(x=date.ref, y=price.close, color=price.close/ppc)) +
    scale_color_gradient2(low="green",mid="yellow",high="red", midpoint = 1, name="price/patr.") +
    geom_line() +
    labs(title="HGLG11 | Price Close",subtitle = "Last 12 Months") +
    theme_light()

extractProventos(fii_info[1,]$updates[[1]]) %>% 
  select(data.base, cota.base, rendimento) %>% 
  filter(data.base >= now()-years(1)) %>% 
  ggplot(aes(data.base, rendimento)) +
  geom_col() +
  theme_minimal()
  
  
