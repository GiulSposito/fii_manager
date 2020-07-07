library(tidyverse)
library(lubridate)
library(ggrepel)

# carrega datasets
port <- readRDS("./data/portfolio.rds")
fii_lupa <- readRDS("./data/fii_lupa.rds")
fii_info <- readRDS("./data/fii_info.rds")

# tickers selecionados para visualização
sel_tickers <- read_table("./import/tickers_recomendados.txt", col_names = F) %>% 
  set_names(c("ticker")) %>% 
  bind_rows(select(port, ticker)) %>% 
  distinct() %>% 
  arrange(ticker) %>% 
  filter(ticker!="TBOF11") # removido

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

prov %>%
  mutate(mes.base = floor_date(data.base, "months")) %>% 
  filter(mes.base >= FIRST_MONTH, mes.base <= LAST_MONTH ) %>% 
  select(ticker, mes.base, valor, cota.base, rendimento) %>% 
  right_join(crossp, by = c("ticker", "mes.base")) %>% 
  filter(ticker %in% c("XPML11","HTMX11","BCFF11")) %>% 
  arrange(ticker, mes.base) %>% 
  mutate( valor      = if_else(is.na(valor),0.0,valor),
          rendimento = if_else(is.na(rendimento),0.0,rendimento) ) %>% 
  group_by(ticker) %>% 
  summarise( 
    rend.md = mean(rendimento),
    rend.sd = sd(rendimento) ) 
  
prov %>% 
  mutate(mes.base = floor_date(data.base, "months")) %>% 
  filter(mes.base >= FIRST_MONTH, mes.base <= LAST_MONTH ) %>% 
  filter(ticker %in% c("XPML11","HTMX11","BCFF11")) %>% 
  group_by(ticker) %>% 
  summarise(
    rend.md = sum(rendimento)/MONTHS,
    rend.sd = sd(rendimento)
  ) %>% 
  mutate( rend.md = rend.md )

sd(c(0.358,0.427))
sd(c(0.427,0.358,0,0,0))

sd(c(0.513,0.563,0.538,0.506,0.466))

# fii_info %>% 
#   mutate(check = map_chr(proventos,function(.x){
#     class(.x$rendimento)
#   })) %>% 
#   filter(check!="numeric")

fii <- fii_lupa$data %>% 
  select(ticker=codneg, tipo, ppc, cvp)

capital <- port %>% 
  group_by(ticker) %>% 
  summarise(capital=sum(value))


prov %>%
  filter(data.base>=now()-months(12)) %>% 
  group_by(ticker) %>% 
  summarise(
    rend.2020 = mean(rendimento), 
    sd.2020   = sd(rendimento)
  ) %>% 
  ungroup() %>% 
  inner_join(fii, by="ticker") %>% 
  filter(cvp>=0.01, ticker!="NEWU11" ) %>% 
  #left_join(capital, by="ticker") %>% 
  # mutate(cvp=cvp-1) %>% 
  # filter(tipo %in% unique(fii$tipo)[c(2,4,5,6,10)]) %>% View()
  ggplot(aes(x=sd.2020, y=rend.2020, color=cvp)) +
  geom_point() + # aes(shape=is.na(capital))
  scale_color_gradient2( low="darkgreen", mid="gold", high="darkred", 
                         midpoint = 1, name = "Cota/Patr.") +
  # scale_color_gradientn(colours = c("darkgreen","green","red","darkred"), values=c(-.5,-0.01,0.01,.5)) +
  geom_text_repel(aes(label=ticker)) +
  labs(
    x="Variação (SD) dos Proventos", 
    y="Média dos Proventos (provento/cota base)", 
    title="Lajes Corporativas em 2020",
    subtitle = "Valor x Variação mensal dos proventos vs Relação Cota/Valor Patrimonial",
    caption = "Dados: https://www.fii.com.br"
  ) +
  theme_light()





