library(tidyverse)
library(ggrepel)
library(lubridate)
source("./R/import/portfolioGoogleSheets.R")

# pega o portfolio do google drive
port <- updatePortfolio()

rec_port <- unique(c("BRCR11","BRCO11","BTLG11","HSML11","HSLG11","KNCR11","KNSC11",
                     "PVBI11","RBRP11","RBRR11","RCRB11","SDIL11","VILG11","BTCR11",
                     "HGCR11","HGPO11","KNRI11","MALL11","MCCI11","ONEF11","PATL11",
                     "TEPP11","VINO11","VTLT11","AIEC11","BTRA11","KNCA11","HFOF11",
                     "RBRF11","RVBI11"))

fiis <- readRDS("./data/fii_info.rds")

dt_fiis <- fiis %>% 
  filter(ticker %in% port$ticker) %>% 
  select(ticker, proventos) %>% 
  unnest(proventos) %>% 
  # filter( !(ticker == "CBOP11" & data.pagamento == ymd("2022-01-14")) ) %>% 
  # filter( !(ticker == "HGRE11" & data.pagamento == ymd("2022-01-14")) ) %>% 
  select(-date.time, -content) %>% 
  filter((data.pagamento%--%now())/months(1)<=12) %>% 
  mutate(recomendado = case_when(
    ticker %in% rec_port ~ T,
    T ~ F
  )) %>% 
  group_by(ticker) %>%
  mutate( rend.mean = mean(rendimento),
          rend.sd = sd(rendimento)) %>% 
  ungroup()

rend.all.median <- median(dt_fiis$rendimento)
rend.all.quant <- quantile(dt_fiis$rendimento)
rend.all.sd     <- median(dt_fiis$rend.sd)

dt_fiis %>% 
  select(ticker, rend.mean, rend.sd, recomendado) %>% 
  distinct() %>% 
  ggplot(aes(x=rend.sd, y=rend.mean,color=recomendado)) +
  geom_point( size=3) +
  geom_text_repel(aes(label=ticker)) +
  geom_hline(yintercept = rend.all.median) +
  geom_hline(yintercept = rend.all.quant[2], linetype="dashed") +
  geom_vline(xintercept = rend.all.sd) +
  theme_light()


fiis %>% 
  filter( ticker == "KNRI11") %>% 
  unnest(proventos) 

