library(xlsx)
library(janitor)
library(tidyverse)

plan <- read.xlsx("./import/Guia+de+FIIs+-+Database+20190215.xlsx", 2,
                  header = F, encoding = "UTF-8", stringAsFactors=F,
                  dec=",")  %>% 
  as.tibble()

plan %>% 
  janitor::remove_empty(c("rows","cols")) %>% 
  filter(!is.na(X4)) %>% 
  View()


?read.xlsx

?read.xlsx2
