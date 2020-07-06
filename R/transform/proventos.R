library(tidyverse)

extractProventos <- function(tickers_updates) {
  tickers_updates %>% 
    # detecta e classifica se o update é uma distribuição/rendimento
    # também checka se é uma correção
    mutate(
      content = tolower(content),
      is.about.rend = str_detect(content,".*distribuição.*rendimento.*"),
      is.rend.fix   = str_detect(content,"(corrigiu|correção)")
    ) %>% 
    # para os que são informe de rendimentos tenta extrari as informações
    filter(is.about.rend) %>% 
    mutate(
      numbers = map(content, function(.x){
        toupper(.x) %>% 
          # extrai números do texto: valor, data, data, valor, decimal em um lista
          str_extract_all("(\\d\\d\\/\\d\\d\\/\\d+)|(R\\$ \\d+,\\d*)|(R\\$ \\d+)|(\\d+,\\d*)",T) %>% 
          # colapsa a lista e limpa pontuação decimal e simbolos de dinheiro
          paste(collapse = "|") %>% 
          str_replace_all(",",".") %>% 
          str_remove_all("R\\$ *")
      })
    ) %>% 
    # requebra a string em colunas do datafame
    separate(
      col   = numbers, 
      into  = c("valor","data.pagamento","data.base","cota.base","rendimento"), 
      sep   = "\\|",
      convert = T,
      extra = "drop"
    ) %>%
    # corrigem tipagem de datas
    mutate(
      data.pagamento = dmy(data.pagamento),
      data.base = dmy(data.base)
    ) %>% 
    # devolve o dataframe 
    select(date.time, correcao=is.rend.fix, valor, data.pagamento, data.base, cota.base, rendimento, content) %>% 
    filter(complete.cases(.)) %>% 
    mutate( valor=as.numeric(valor) ) %>% 
    return()
}
