library(readr)
library(stringr)
library(tidyverse)
library(lubridate)

extrato <- readr::read_csv2("./import/Extrato_2019-03-12.csv") %>% 
  set_names(c("dt_liq", "dt_mov", "historico", "lancamento", "saldo", "codigo")) 
    
extrato %>%
  mutate(
    dt_liq = dmy(dt_liq),
    dt_mov = dmy(dt_mov),
    month  = month(dt_mov),
    ticker = historico %>% str_extract("ACOES ......") %>% str_sub(start = 7),
    prov.dist = historico %>% str_detect("(RENDIMENTO)|(DISTRIBUICAO)|(JUROS)"),
    volume    = extrato$historico %>% str_extract("(?<=S/ )[0-9]+") %>% as.integer()
  ) %>% 
  filter( prov.dist==T, !is.na(volume) ) %>% 
  group_by(month) %>% 
  summarise( proventos = sum(lancamento) )

extrato$historico %>% 
  str_extract("(?<=DEB )(\\w)+")

  
  
