library(tidyverse)
library(lubridate)


tibble(
  ticker = c("RBRF11","RBRR11","CTPS11B","KNIP11","XPLG11",
             "HGLG11","SDIL11","XPML11","HGRE11"),
  mes = floor_date(now(), "month"),
  carteira = "xp"
) %>% 
  saveRDS("./data/carteira_recomendada_xp.rds")


library(tabulizer)

itau_tables <- extract_tables("./import/carteira_itau.pdf")

ittb <- itau_tables[[3]]

tibble(
  ticker = ittb[6:11,2],
  mes = floor_date(now(), "month"),
  carteira = "itau"
) %>% 
  saveRDS("./data/carteira_recomendada_itau.rds")
