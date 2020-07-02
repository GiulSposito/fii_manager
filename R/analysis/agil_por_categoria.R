result$dict

result$data %>% 
  filter(codneg!="RBCB11", cvp!=0) %>% 
  # mutate(tipo=ifelse(tipo=="Híbrido (Tijolo/Papel)", "Tijolo: Híbrido", tipo)) %>% 
  group_by(tipo) %>% 
  summarise(
    cvp=mean(cvp)-1,
    n=n()
  ) %>% 
  ungroup() %>%
  mutate(tipo = fct_reorder(tipo, cvp)) %>% 
  filter(complete.cases(.)) %>% 
  arrange(desc(cvp)) %>% 
  ggplot(aes(x=tipo, y=cvp, fill=cvp>0, color=cvp>0)) +
  geom_col(width=.1) +
  geom_point(size=4) +
  coord_flip() +
  theme_minimal() +
  theme(legend.position = "none") +
  labs(title="FII: Ágil de Mercado em Relação ao Patrimônio",
       subtitle = "",
       y="Ágil entre vm/vp",x="Tipo de FII")

result$data %>% 
  filter(tipo=="Híbrido (Tijolo/Papel)") %>% 
  arrange(desc(cvp))


