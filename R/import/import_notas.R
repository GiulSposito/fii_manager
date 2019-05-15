library(tidyverse)
library(googlesheets)
library(lubridate)

# import data
gs_auth()


# function to deal with formatted money from spreadsheet
.parseRealValue <- function(x) parse_number(
  gsub(pattern = "R$ *", replacement = "", x = x), 
  locale=locale(grouping_mark=".", decimal_mark=",")
)

# spreadsheet
.key <- "1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU"

# import tab with notas de necociacao
spreadsheet <- gs_key(.key) %>%
  gs_read(ws="Notas", col_types=c("Dicciicc")) %>%
  as.tibble()

# trata dados
notas <- spreadsheet%>% 
  mutate(
    price = .parseRealValue(price),
    buy.value = .parseRealValue(buy.value),
    sell.value = .parseRealValue(sell.value),
    op.type = case_when(
      buy == 0  ~ "sell",
      sell == 0 ~ "buy",
      TRUE ~ "NA"
    ),
    value = map2_dbl(buy.value, sell.value, max)
  )


port <- notas %>% 
  mutate( 
    balance = buy.value - sell.value,
    volume  = buy - sell
  ) %>% 
  group_by(data.operacao, ticker, price) %>% 
  summarise(
    capital = sum(balance), 
    volume   = sum(volume)
  ) %>% 
  filter(volume>0)

port %>% View()
