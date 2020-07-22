library(tidyverse)
library(lubridate)
library(ggrepel)

# carrega datasets
port <- readRDS("./data/portfolio.rds")
fii_lupa <- readRDS("./data/fii_lupa.rds")
fii_info <- readRDS("./data/fii_info.rds")

##### tickers selecionados para visualização

# CARTEIRAS RECOMENDADAS + PORTIFOLIO
# sel_tickers <- read_table("./import/tickers_recomendados.txt", col_names = F) %>% 
#   set_names(c("ticker")) %>% 
#   bind_rows(select(port, ticker)) %>% 
#   distinct() %>% 
#   arrange(ticker) %>% 
#   filter(ticker!="TBOF11") # removido

# POR CATEGORIA
sel_tickers <- fii_lupa$data %>% 
  filter(tipo=="Tijolo: Shoppings") %>% 
  select(ticker=codneg, tipo)

# pega os proventos
source("./R/import/fixProventos.R")
prov <- fii_info %>% 
  inner_join(sel_tickers, by="ticker") %>% 
  select(ticker, proventos) %>% 
  unnest(proventos) %>%
  fixProventos()


# Parametros de consulta
MONTHS <- 6
LAST_MONTH <- floor_date(today()-months(1),"months")
FIRST_MONTH <- LAST_MONTH-months(MONTHS-1)

# expand um cross product Ticker x Mes para garantir
# que apareçam no dataframe, meses que não 
crossp <- unique(prov$ticker) %>% 
  expand.grid(seq(from=FIRST_MONTH, to=LAST_MONTH, by="months")) %>% 
  as_tibble() %>% 
  set_names(c("ticker","mes.base"))

# solução vê os meses faltando como 0 de provento
prov_metrics <- prov %>%
  mutate(mes.base = floor_date(data.base, "months")) %>% 
  filter(mes.base >= FIRST_MONTH, mes.base <= LAST_MONTH ) %>% 
  select(ticker, mes.base, valor, cota.base, rendimento) %>% 
  right_join(crossp, by = c("ticker", "mes.base")) %>% 
  #filter(ticker %in% c("XPML11","HTMX11","BCFF11")) %>% 
  arrange(ticker, mes.base) %>% 
  mutate( valor      = if_else(is.na(valor),0.0,valor),
          rendimento = if_else(is.na(rendimento),0.0,rendimento) ) %>% 
  group_by(ticker) %>% 
  summarise( 
    rend.md = mean(rendimento),
    rend.sd = sd(rendimento) ) 
  
# SOLUÇÃO SEM FAZER CROSS PRODUCT 
# não vê os zeros
# 
# prov %>% 
#   mutate(mes.base = floor_date(data.base, "months")) %>% 
#   filter(mes.base >= FIRST_MONTH, mes.base <= LAST_MONTH ) %>% 
#   filter(ticker %in% c("XPML11","HTMX11","BCFF11")) %>% 
#   group_by(ticker) %>% 
#   summarise(
#     rend.md = sum(rendimento)/MONTHS,
#     rend.sd = sd(rendimento)
#   ) %>% 
#   mutate( rend.md = rend.md )

# fii_info %>% 
#   mutate(check = map_chr(proventos,function(.x){
#     class(.x$rendimento)
#   })) %>% 
#   filter(check!="numeric")

fii <- fii_lupa$data %>% 
  select(ticker=codneg, tipo, ppc, cvp, patrimonio)


prov_metrics %>%
  inner_join(fii, by="ticker") %>% 
  filter(cvp <= 0.90) %>% 
  ggplot(aes(x=rend.sd, y=rend.md, color=cvp)) +
  geom_point() + # aes(shape=is.na(capital))
  scale_color_gradient2( low="darkgreen", mid="gold", high="darkred", 
                         midpoint = 1, name = "Cota/Patr.") +
  # scale_color_gradientn(colours = c("darkgreen","green","red","darkred"), values=c(-.5,-0.01,0.01,.5)) +
  geom_text_repel(aes(label=ticker)) +
  labs(
    x="Variação (SD) dos Proventos", 
    y="Média dos Proventos (provento/cota base)", 
    title="FIIs: Shoppings (2020)",
    subtitle = "Valor x Variação mensal dos proventos vs Relação Cota/Valor Patrimonial",
    caption = "Dados: https://www.fiis.com.br"
  ) +
  theme_light()

port %>% 
  group_by(ticker) %>% 
  summarise( capital = sum(value) ) %>% 
  mutate( portifolio = capital/sum(capital)) %>% 
  arrange(desc(capital)) %>% 
  View()

port %>% 
  inner_join(fii, by="ticker") %>% 
  group_by(ticker, tipo) %>% 
  summarise(capital= sum(value)) %>% 
  mutate(proporcao = capital/sum(capital)) %>% 
  arrange(desc(capital)) %>% View()


