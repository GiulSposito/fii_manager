prov <- readRDS("./data/fii_proventos.rds")

prov %>% 
  summary()

# check proventos health
prov %>% 
  mutate(
    data.pagamento = case_when(
      (data.pagamento == ymd(21081214)) & (ticker=="VISC11") ~ ymd(20181214),
      T ~ data.pagamento
    )
  ) %>% saveRDS("./data/fii_proventos.rds")
