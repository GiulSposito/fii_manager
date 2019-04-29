# import os proventos do site www.fiis.com.br
port$ticker %>% 
  c("SDIL11","VGIR11","HGRU11","IRDM11", "RBRF11", "RBRR11","TRLX11","THRA11") %>% 
  unique() %>% 
  sort() %>% 
  importProventos() %>% 
  filter( complete.cases(.) ) -> prov.updt

# visualiza datas minimas
prov.updt %>% 
  group_by( ticker ) %>% 
  filter( data.pagamento == min(data.pagamento, na.rm = T))

# conta os proventos por mes e pegando ticker e mês que tem mais de um
prov.updt %>% 
  filter( complete.cases(.) ) %>% 
  mutate( data.mes = floor_date(data.pagamento, unit = "months")) %>% 
  group_by( ticker, data.mes ) %>% 
  summarise( count=n() ) %>% 
  filter( count > 1 ) -> prov.duplicado

# recupera as entradas dos proventos que caem no mesmo mês
prov.updt %>% 
  filter( complete.cases(.) ) %>% 
  mutate( data.mes = floor_date(data.pagamento, unit = "months")) %>%  
  inner_join(prov.duplicado)

# pega os proventos que são classificados como correção
prov.updt %>% 
  filter( complete.cases(.),
          correcao==T ) %>% 
  mutate( mes.pagamento = floor_date(data.pagamento, unit = "months")) -> correcoes

# pega os proventos não macados como correção
prov.updt %>% 
  filter( complete.cases(.),
          correcao==F ) %>% 
  mutate( mes.pagamento = floor_date(data.pagamento, unit = "months")) -> proventos

# substitui os proventos "corrigidos" pela correção
proventos %>% 
  anti_join(correcoes, by=c("ticker","mes.pagamento")) %>% 
  bind_rows(correcoes) %>% 
  arrange(ticker, desc(data.update)) %>% 
  select(-mes.pagamento, -correcao) -> prov.corrigidos

# corrige um provento com data de 2108 (VISC11)
prov.corrigidos %>% 
  mutate(
    data.pagamento = case_when(
      data.pagamento == ymd("21081214") ~ ymd("20181214"),
      TRUE ~ data.pagamento 
    )
  ) -> prov.corrigidos

# salva proventos
saveRDS(prov.corrigidos, "./data/fii_proventos.rds")

# plota o valor dos proventos ao longo do tempo 
# para visualizar "splits" de ações
prov.corrigidos %>% 
  select(ticker, data.pagamento, valor) %>% 
  ggplot(aes(x=data.pagamento, y=valor, group=ticker)) + 
  geom_line(aes(color=ticker)) +
  theme_minimal() -> g
library(plotly)
ggplotly(g)

# tabela de proventos splitados com base na data de pagamento (precisa ver isso aí!)
splited.tickers <- c("HGBS11", "HGRE11", "HGLG11", "GRLV11", "CBOP11")
splited.proventos <- tibble(
  ticker = splited.tickers,
  split.date   = rep(ymd(20180413),length(splited.tickers)),
  split.factor = rep(0.1, length(splited.tickers))
)

# visualiza distribuição mensal dos proventos splitados
prov.corrigidos %>%
  filter( ticker %in% splited.tickers ) %>% 
  select(ticker, data.pagamento, valor) %>% 
  ggplot(aes(x=data.pagamento, y=valor, group=ticker)) + 
  geom_line(aes(color=ticker)) +
  theme_minimal() -> g
ggplotly(g)

# corrige os proventos que sofreram split e plota
prov.corrigidos %>% 
  left_join(splited.proventos, by="ticker") %>% 
  mutate(
    valor     = case_when( ( !is.na(split.factor) & (data.pagamento <= split.date)) ~ valor     * split.factor, TRUE ~ valor ),
    cota.base = case_when( ( !is.na(split.factor) & (data.pagamento <= split.date)) ~ cota.base * split.factor, TRUE ~ cota.base )
  ) %>%
  select(ticker, data.pagamento, valor) %>% 
  ggplot(aes(x=data.pagamento, y=valor, group=ticker)) + 
  geom_line(aes(color=ticker)) +
  theme_minimal() -> g
ggplotly(g)

# corrige proventos
prov.corrigidos %>% 
  left_join(splited.proventos, by="ticker") %>% 
  mutate(
    valor     = case_when( ( !is.na(split.factor) & (data.pagamento <= split.date)) ~ valor     * split.factor, TRUE ~ valor ),
    cota.base = case_when( ( !is.na(split.factor) & (data.pagamento <= split.date)) ~ cota.base * split.factor, TRUE ~ cota.base )
  ) %>% 
  select( -split.date, -split.factor ) -> prov.corr.splited

prov.corr.splited %>% 
  saveRDS("./data/fii_proventos.rds")
