library(ggrepel)
source("./R/import/proventos_v2.R")

tickers <- c("XPML11", "XPIN11", "RBRR11", "HGBS11", "RBRF11",
             "FVBI11", "FFCI11", "BRCR11", "TBOF11", "HTMX11",
             
             "MALL11", "JSRE11", "HGRE11", "VISC11", "KNCR11",
             "HGLG11", "ABCP11", "KNRI11", "TRXL11",
             
             "ALMI11", "TBOF11", "CEOC11", "CNES11", "RNGO11",
             "VLOL11", "THRA11", "RBBV11",
             
             "BCFF11", "BMLC11B","CBOP11", "GGRC11","GRLV11",
             "HFOF11", "HGRE11", "MXRF11", "XPCM11", "SDIL11")


provs <- importProventos(tickers)

provs %>% 
  filter(ticker!="ALMI11") %>% 
  group_by(ticker) %>% 
  filter(data.pagamento>= now()-months(12)) %>% 
  filter(
    !(rendimento == max(rendimento) | rendimento == min(rendimento))
  ) %>% 
  summarise(
    avg = mean(rendimento),
    sd  = sd(rendimento),
    count = n()
  ) %>% 
  arrange(desc(avg), sd) -> prov.summ

prov.summ %>% 
  mutate(ticker=as.factor(ticker)) %>% 
  ggplot(aes(x=sd, y=avg)) +
    geom_point(aes(color=count, size=count)) +
    geom_label_repel(aes(label=ticker),size=2) +
    theme_minimal()

prov.summ %>% 
  arrange(desc(sd))

provs %>% 
  filter(ticker=="ALMI11")

prov.summ %>% inner_join(retornos, by="ticker") -> carteira

carteira %>% 
  ggplot(aes(x=sd, y=avg, size=value, color=tr)) +
  geom_point() +
  scale_color_continuous(low="red", high = "green") +
  geom_label_repel(aes(label=ticker),size=2) +
  theme_minimal()

