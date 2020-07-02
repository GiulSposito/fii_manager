c(1, 3, 6, 12, 24) %>% 
  map(function(m, p){
    resp <- p %>% 
      filter(!(ticker=="BRCR11" & data.base==ymd(20190313))) %>% #outlier do BRCR11 
      filter( data.pagamento >= now()-months(m) ) %>% 
      group_by(ticker) %>%  #, in.portfolio) %>% 
      summarise(
        cotacao = mean(cota.base),
        retorno = mean(rendimento),
        volat   = sd(rendimento),
      ) %>% 
      ungroup() %>% 
      mutate(min.retorno = retorno - volat) %>% 
      arrange(desc(min.retorno)) %>% 
      select(-min.retorno) %>% 
      set_names(paste0(names(.),".L",m,"M"))
    
    names(resp)[1] <- "ticker"
    return(resp)
  }, p=prov) %>% 
  reduce(left_join, by="ticker") %>% 
  select(ticker, starts_with("retorno"), starts_with("volat"), everything()) %>% 
  write_excel_csv("./export/portfolio_proventos.csv")
