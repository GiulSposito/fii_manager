library(rvest)
library(purrr)
library(dplyr)
library(janitor)
library(lubridate)

page <- xml2::read_html("./import/empiricus.html")

tables <- page %>% 
  html_nodes("table") %>% 
  html_table()

types <- list("Empiricus Renda","Empiricus Capital","Empiricus FoF",
           "Empiricus Iliquida","Empiricus Três Cabeças")

purrr::map2_df(tables, types, ~mutate(.x, carteira=.y)) %>% 
  mutate( mes = floor_date(now(), unit = "month") ) %>% 
  set_names(janitor::make_clean_names(names(.))) %>% 
  select(mes, carteira, everything()) %>%
  rename(tipo = objeto) %>% 
  saveRDS("./data/carteira_recomendada_empiricus.rds")
