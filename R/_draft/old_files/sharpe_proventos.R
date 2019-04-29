library(ggrepel)
library(ggplot2)

prov %>% 
  filter(data.pagamento>now()-months(12)) %>% 
  group_by(ticker) %>% 
  summarise(
    rend.mean = mean(rendimento),
    rend.sd   = sd(rendimento),
    rend.count = n()
  ) %>% 
  mutate( rend.count = as.factor(rend.count) ) %>% 
  ggplot(aes(x=rend.sd, y=rend.mean)) +
  geom_label_repel(aes(label=ticker), size=2.3) +
  geom_point(aes(color=rend.count)) +
  theme_minimal()


prices <- readRDS("./data/price.rds")
glimpse(prices)

prices %>% 
  filter(ticker != "IFIX") %>% 
  group_by(ticker) %>% 
  summarise(
    price.mean = mean(price.close, na.rm = T),
    price.sd   = sd(price.close, na.rm = T)
  ) %>% 
  ggplot(aes(x=price.sd, y=price.mean)) +
  geom_label_repel(aes(label=ticker), size=2.3) +
  theme_minimal()
