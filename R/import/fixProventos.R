
# script to fix incorrect proventos and handle "corrction" info
fixProventos <- function(.proventos){
  
  # pega os proventos que são classificados como correção
  .proventos %>% 
    filter( complete.cases(.),
            correcao==T ) %>% 
    mutate( mes.pagamento = floor_date(data.pagamento, unit = "months")) -> correcoes
  
  # pega os proventos não macados como correção
  .proventos %>% 
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
  
  # tabela de proventos splitados com base na data de pagamento (precisa ver isso aí!)
  splited.tickers <- c("HGBS11", "HGRE11", "HGLG11", "GRLV11", "CBOP11", "HGJH11")
  splited.proventos <- tibble(
    ticker = splited.tickers,
    split.date   = rep(ymd(20180413),length(splited.tickers)),
    split.factor = rep(0.1, length(splited.tickers))
  )
  
  # corrige proventos
  prov.corrigidos %>% 
    left_join(splited.proventos, by="ticker") %>% 
    mutate(
      valor     = case_when( ( !is.na(split.factor) & (data.pagamento <= split.date)) ~ valor     * split.factor, TRUE ~ valor ),
      cota.base = case_when( ( !is.na(split.factor) & (data.pagamento <= split.date)) ~ cota.base * split.factor, TRUE ~ cota.base )
    ) %>% 
    select( -split.date, -split.factor ) %>% 
    distinct() -> prov.corr.splited
  
  # retorna correcoes e splits
  return(prov.corr.splited)
  
}
