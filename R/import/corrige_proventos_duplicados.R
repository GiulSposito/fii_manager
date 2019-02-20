prov <- readRDS("./data/fii_proventos.rds")

# check proventos health
prov %>% 
  mutate( pay.month = month(data.pagamento),
          pay.year  = year(data.pagamento) ) %>% 
  group_by(ticker, pay.year, pay.month) %>% 
  summarise(
    count = n()
  ) %>% 
  filter(count>1) %>% 
  View()

prov %>% 
  mutate( pay.year  = year(data.pagamento),
          pay.month = month(data.pagamento)) %>% 
  group_by(ticker, pay.year, pay.month) %>% 
  summarise( rendimentos = sum(valor) ) %>% 
  ungroup() %>% 
  mutate( data.pagamento = ymd(paste(pay.year, pay.month, 1, sep="-") ) ) %>% 
  select( -pay.year, -pay.month ) %>% 
  spread(ticker, rendimentos) %>% View()

# correcoes
prov %>% 
  filter( !(ticker=="FIIB11" & data.update == ymd(20160930)) ) %>% 
  filter( !(ticker=="GGRC11" & data.update == ymd(20180702)) ) %>% 
  filter( !(ticker=="HGRE11" & data.update==ymd(20180928) & valor == 0.58 ) ) %>% 
  filter( !(ticker=="JSRE11" & data.pagamento == ymd(20180223)) ) %>% 
  filter( !(ticker=="MALL11" & data.update == ymd(20180131)) ) %>% 
  filter( !(ticker=="MXRF11" & data.pagamento== ymd(20170914)) ) %>% 
  filter( !(ticker=="VISC11" & data.pagamento== ymd(20180514)) ) %>% 
  filter( !(ticker=="VLOL11" & data.base == ymd(20181031)) ) %>% 
  saveRDS("./data/fii_proventos.rds")
