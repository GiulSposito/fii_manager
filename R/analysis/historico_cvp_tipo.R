library(tidyverse)
library(lubridate)
library(gganimate)

lupa <- readRDS("./data/fii_lupa.rds")
info <- readRDS("./data/fii_info.rds")

lupa$dict

lp_data <- lupa$data %>% 
  rename(ticker=codneg) %>% 
  filter(complete.cases(.)) %>% 
  select(ticker, tipo, ppc, cvp, ncotistas, patrimonio) %>% 
  mutate( ncotas = round(patrimonio/ppc),
          valor  = patrimonio/ncotas )
          
price <- info %>% 
  select(price) %>% 
  unnest(price) %>% 
  filter(date.ref >= ymd(20200101))


lp_data %>% 
  select(-ncotistas) %>% 
  inner_join(price) %>% 
  mutate(ncvp = ncotas * price.close / patrimonio ) %>% 
  filter(ticker!="RBCB11", cvp!=0) %>% 
  group_by(tipo, date.ref) %>%
  summarise(ncvp=mean(ncvp)) %>% 
  ungroup() %>% 
  mutate(ticker=factor(tipo)) %>% 
  ggplot(aes(date.ref, ncvp, color=ticker)) +
  geom_line() +
  theme_minimal()



lp_data %>% 
  select(-ncotistas) %>% 
  inner_join(price, by = "ticker") %>% 
  mutate(ncvp = ncotas * price.close / patrimonio ) %>% 
  filter(ticker!="RBCB11", cvp!=0) %>% 
  group_by(tipo, date.ref) %>%
  summarise(ncvp=mean(ncvp)) %>% 
  ungroup() %>% 
  mutate(ticker=factor(tipo),
         ncvp = ncvp-1) %>% 
  ggplot(aes(x=tipo, y=ncvp, fill=ncvp>0, color=ncvp>0)) +
  geom_col(width=.1) +
  geom_point(size=4) +
  coord_flip() +
  theme_minimal() +
  theme(legend.position = "none") +
  labs(title="FII: Ágil de Mercado em Relação ao Patrimônio",
       subtitle = "{frame_time}",
       y="Ágil entre vm/vp",x="Tipo de FII") +
  transition_time( date.ref )



lp_data %>% 
  select(-ncotistas) %>% 
  inner_join(price, by = "ticker") %>% 
  mutate(ncvp = ncotas * price.close / patrimonio ) %>% 
  filter(ticker!="RBCB11", cvp!=0) %>% 
  group_by(tipo, date.ref) %>%
  summarise(ncvp=mean(ncvp)) %>% 
  ungroup() %>% 
  mutate(ticker=factor(tipo),
         ncvp = ncvp-1,
         tipo = fct_reorder(tipo, ncvp)) %>% 
  ggplot(aes(x=tipo, y=ncvp, fill=ncvp>=0, color=ncvp>=0)) +
  geom_col(width=.1, stat="identidy") +
  geom_point(size=4) +
  coord_flip() +
  theme_minimal() +
  theme(legend.position = "none") +
  labs(title="FII: Histórico entre Valor Mercado x Valor Patrimonial",
       subtitle = "{frame_time}",
       y="Ágil (1-vm/vp)",x="Tipo de FII", caption = "Fonte: https://www.fiis.com.br") +
  transition_time( date.ref ) +
  enter_appear() + exit_disappear() +
  theme(plot.caption = element_text(hjust = 0))


animate(p, end_pause = 5)
anim_save("./export/fii_cvp_historico.gif")

gganimate::
