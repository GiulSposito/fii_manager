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

# Radar (prov 2020 x sd 2020)
prov <- fii_info %>% 
  inner_join(sel_tickers, by="ticker") %>% 
  select(ticker, proventos) %>% 
  unnest(proventos)


# check de meses por ticker
prov %>% 
  filter(data.base >= ymd(20200101)) %>% 
  mutate(mes.pagamento = floor_date(data.base, "months")) %>% 
  count(ticker, sort = T) %>% 
  View()

crossp <- c("XPML11","HTMX11","BCFF11") %>% 
  expand.grid(seq(from=ymd(20200101), to=ymd(20200601), by="months")) %>% 
  as_tibble() %>% 
  set_names(c("ticker","mes.pagamento"))

prov %>%
  filter(data.base >= ymd(20200101)) %>% 
  filter(ticker %in% c("XPML11","HTMX11","BCFF11")) %>% 
  mutate(mes.pagamento = floor_date(data.base, "months")) %>% 
  select(ticker, mes.pagamento, valor, cota.base, rendimento) %>% 
  right_join(crossp, by = c("ticker", "mes.pagamento")) %>% 
  arrange(ticker, mes.pagamento) %>% 
  mutate( valor      = if_else(is.na(valor),0,valor),
          rendimento = if_else(is.na(rendimento),0,rendimento) ) %>% 
  group_by(ticker) %>% 
  mutate( rend.md = mean(rendimento) ) %>% 
  group
  


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





