library(tidyverse)
library(googlesheets)
library(lubridate)

# function to deal with formatted money from spreadsheet
parseRealValue <- function(x) parse_number(
    gsub(pattern = "R$ *", replacement = "", x = x), 
    locale=locale(grouping_mark=".", decimal_mark=",")
  )

# key for my personal spreadsheet
key <- "1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU"
gs_auth()

# import data
spreadsheet <- gs_key(key) %>%
  gs_read(ws=1) %>%
  as.tibble()

# format data types
portfolio <- spreadsheet %>% 
  select(Data, Ativo, Qtd, Valor, Taxas, Total, Carteira) %>%
  setNames(c("date","ticker","volume","price","taxes", "value", "portfolio")) %>%
  filter(complete.cases(.)) %>%
  mutate(
    price = parseRealValue(price),
    taxes   = parseRealValue(taxes),
    value   = parseRealValue(value),
    portfolio = as.factor(portfolio),
    date    = ymd(date)
  )

# save it locally
portfolio %>% 
  saveRDS("./data/portfolio.rds")

getPortfolio <- function(fname="./data/portfolio.rds"){
  readRDS(fname) %>%
    return()
}
