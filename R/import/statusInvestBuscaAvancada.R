library(tidyverse)

statusinvestBuscaAvancadaFIIs_importer <- function(file="./import/statusinvest-busca-avancada-20251124.csv"){
  read_delim(file, delim=";", locale = locale(decimal_mark=",")) |> 
    janitor::clean_names() |> 
    distinct()
} 
