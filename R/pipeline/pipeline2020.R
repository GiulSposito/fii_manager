source("./R/import/portfolioGoogleSheets.R")
source("./R/api/ffis_api.R")
source("./R/api/import_lupa.R")
library(ggrepel)

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

# pega os tickers para importar dados de cotação
sel_tickers <- fii_lupa$data$codneg

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

# Radar (prov 2020 x sd 2020)
prov <- fii_info %>% 
  select(ticker, proventos) %>% 
  filter(ticker != "TBOF11") %>% 
  unnest(proventos)

# fii_info %>% 
#   mutate(check = map_chr(proventos,function(.x){
#     class(.x$rendimento)
#   })) %>% 
#   filter(check!="numeric")

fii <- fii_lupa$data %>% 
  select(ticker=codneg, tipo, ppc, cvp)

capital <- port %>% 
  group_by(ticker) %>% 
  summarise(capital=sum(value))


prov %>%
  filter(data.base>=now()-months(12)) %>% 
  group_by(ticker) %>% 
  summarise(
    rend.2020 = mean(rendimento), 
    sd.2020   = sd(rendimento)
  ) %>% 
  ungroup() %>% 
  inner_join(fii, by="ticker") %>% 
  filter(cvp>=0.01, ticker!="NEWU11" ) %>% 
  #left_join(capital, by="ticker") %>% 
  # mutate(cvp=cvp-1) %>% 
  # filter(tipo %in% unique(fii$tipo)[c(2,4,5,6,10)]) %>% View()
  ggplot(aes(x=sd.2020, y=rend.2020, color=cvp)) +
  geom_point() + # aes(shape=is.na(capital))
  scale_color_gradient2( low="darkgreen", mid="gold", high="darkred", 
                         midpoint = 1, name = "Cota/Patr.") +
  # scale_color_gradientn(colours = c("darkgreen","green","red","darkred"), values=c(-.5,-0.01,0.01,.5)) +
  geom_text_repel(aes(label=ticker)) +
  labs(
    x="Variação (SD) dos Proventos", 
    y="Média dos Proventos (provento/cota base)", 
    title="Lajes Corporativas em 2020",
    subtitle = "Valor x Variação mensal dos proventos vs Relação Cota/Valor Patrimonial",
    caption = "Dados: https://www.fii.com.br"
  ) +
  theme_light()





