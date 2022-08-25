source("./R/import/portfolioGoogleSheets.R")
source("./R/api/ffis_api.R")
source("./R/api/import_lupa.R")
# library(ggrepel)


# pega o portfolio do google drive
port <- updatePortfolio()

# # seleciona os tickers de interesse
# sel_tickers <- sort(unique(port$ticker,c(
#     "HGBS11","LVBI11","RBRP11","HGRU11","KNCR11","HGCR11",
#     "SDIL11","RVBI11","TRXF11","VISC11","KNIP11","CPTS11B",
#     "RBRR11","GTWR11","BTLG11","XPPR11","FVPQ11","HFOF11",
#     "KFOF11","MGFF11","RBRF11","HGPO11","RBBV11","RVBI11",
#     "VTLT11","EDGA11","HSML11","GTWR11"))) 

# importa dados "cadastrais" dos FIIs
fii_lupa <- importLupa()
fii_list <- importFIIList()

# pega os tickers para importar dados de cotação
# sel_tickers <- fii_lupa$data$codneg
sel_tickers <- fii_list

# protege o scrapping de erros
safeGetFIIinfo <- safely(getFIIinfo)

# faz o scrapping
fii_scrap <- sel_tickers %>% 
  map(safeGetFIIinfo, .startDate = now()-years(2))

# avisa os erros de scrapping
fii_scrap %>% 
  map(pluck, "error") %>% 
  map_lgl(~!is.null(.x)) %>% 
  sel_tickers[.] 

# transforma o scrapping do DF de informação
source("./R/transform/proventos.R")
fii_info <- fii_scrap %>%
  keep(~ is.null(.x$error)) %>%     # limpa os erros de scrapping
  map_df(pluck, "result") %>%       # monta um DF com os resultados
  mutate(proventos=map(updates, extractProventos)) # extrai os pronvetos


# update datasets
saveRDS(fii_lupa,"./data/fii_lupa.rds")
saveRDS(fii_info,"./data/fii_info.rds")
