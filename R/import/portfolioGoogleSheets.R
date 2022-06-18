library(tidyverse)
library(googlesheets4)
library(lubridate)

.PORTFOLIO_FILENAME = "./data/portfolio.rds"

# function to deal with formatted money from spreadsheet
.parseRealValue <- function(x) parse_number(
    gsub(pattern = "R$ *", replacement = "", x = x), 
    locale=locale(grouping_mark=".", decimal_mark=",")
  )

# function to repimport FII portfolio from google sheets
updatePortfolio <- function(.file=.PORTFOLIO_FILENAME, .key="1k0u_xV21AUEBzfi_e8rZtiAgEJD2OGsQu0QW-IJ_kCU"){
  
  # import data
  # gs4_auth()
  spreadsheet <- read_sheet(.key)
  
  # format data types
  portfolio <- spreadsheet %>% 
    select(Data, Ativo, Qtd, Valor, Taxas, Total, Carteira) %>%
    setNames(c("date","ticker","volume","price","taxes", "value", "portfolio")) %>%
    filter(complete.cases(.)) %>%
    mutate(
      price = .parseRealValue(price),
      taxes   = .parseRealValue(taxes),
      value   = .parseRealValue(value),
      portfolio = as.factor(portfolio),
      date    = ymd(date)
    )
  
  # save it locally
  portfolio %T>% 
    saveRDS(.file) %>% 
    return()
}

# read Local Portfolio
getPortfolio <- function(fname=.PORTFOLIO_FILENAME){
  readRDS(fname) %>%
    return()
}
