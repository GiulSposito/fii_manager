# import os proventos do site www.fiis.com.br
port$ticker %>% 
  unique() %>% 
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
  inner_join(prov.duplicado) %>% 
  View()

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

splited.proventos <- tibble(
  ticker = c("HGBS11", "HGRE11", "HGLG11", "GRLV11", "CBOP11"),
  date   = rep(ymd(20180403),length(splited.tickers)),
  factor = rep(0.1, length(splited.tickers))
)



prov.corrigidos %>%
  filter( ticker %in% splited.tickers ) %>% 
  select(ticker, data.pagamento, valor) %>% 
  ggplot(aes(x=data.pagamento, y=valor, group=ticker)) + 
  geom_line(aes(color=ticker)) +
  theme_minimal() -> g
ggplotly(g)
