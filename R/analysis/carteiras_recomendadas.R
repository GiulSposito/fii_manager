library(tidyverse)
library(lubridate)
library(ggrepel)

# portifolio
source("./R/import/portfolioGoogleSheets.R")

# dados de fundos
port <- updatePortfolio()
lupa <- readRDS("./data/fii_lupa.rds")
fii  <- readRDS("./data/fii_info.rds")

# tickers das carteiras
sel_tickers <- read_table("./import/tickers_recomendados.txt", col_names = F) %>% 
  set_names(c("ticker")) %>% 
  count(ticker)


# cross product de ticker e mes para garantir zero nas medias
month_ref <- sel_tickers$ticker %>% 
            expand.grid(seq(from=ymd(20200101), to=ymd(20200601), by="months")) %>% 
            as_tibble() %>% 
            set_names(c("ticker","month.base"))


# rendimento medio
sel_tickers %>% 
  inner_join(fii, by="ticker") %>% 
  select(ticker, n, proventos) %>% 
  unnest(proventos) %>% 
  filter(data.base >= ymd(20200101)) %>% 
  mutate(month.base = floor_date(data.base, unit="months") ) %>% 
  select(ticker, n, month.base, rendimento) %>%
  group_by(ticker,n,month.base)
  arrange(ticker, month.base) %>%
  right_join(month_ref, by=c("ticker","month.base")) %>%
  group_by(ticker, n) %>% View()
  summarise(
    rend.mean.2020 = mean(rendimento),
    rend.sd.2020   = sd(rendimento),
    rend.count     = n()
  ) %>% 
  ungroup() %>% 
  View()
  mutate( n= as.factor(n) ) %>% 
  inner_join(lupa$data, by=c("ticker"="codneg")) %>% 
  filter(cvp!=0, cvp <=1 ) %>% 
  select(ticker, n, rend.mean.2020, rend.sd.2020, tipo, ppc, cvp) %>% 
  ggplot(aes(x=rend.sd.2020, y=rend.mean.2020, size=n, color=cvp)) +
  scale_color_gradient2(low="darkgreen",mid="gold", high="darkred", midpoint = 1) +
  geom_point() +
  geom_text_repel(aes(label=ticker), size=3) +
  labs( title =  "Carteiras Recomendas",
        subtitle = "Desenpenho em 2020 | Número de Recomendações | Cota/Val. Patr.",
        caption="dados: www.fiis.com.br",
        x="sd(proventos)", y="mean(proventos)" ) + 
  theme_minimal()


