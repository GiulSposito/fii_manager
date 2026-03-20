# Portfolio ####
library(ggrepel)


# pega da posicao consolidada do Nubank e do XPI
# deve ser diferente do portfolio do gsheet porque tickers mudaram
source("./R/import/nubank_inf_rend_FII_importer.R")
source("./R/import/xpi_pos_cons_FII_importer.R")
source("./R/import/statusInvestBuscaAvancada.R")
source("./R/_draft/statusinvest_proventos.R")

nuPort <- importNuInfRendFii() |> mutate(cust="nu")
xpiPort <- importXpiPosConsFii() |> mutate(cust="xpi")

# unifica, so interessa ticker e quantidad
portCons <- bind_rows(
  select(nuPort, ticker, qtd = cotas2024, cust),
  select(xpiPort, ticker, qtd, cust)
  ) |> 
  filter(qtd!=0)

# FII Info ####
proventos <- portCons |> 
  distinct(ticker) |> 
  filter(!ticker %in% c("MALL11", "KNCA11", "FGAA11","XPLG12", "RVBI11")) |> 
  bind_rows(tibble(ticker="PMLL11")) |>
  mutate(proventos = map(ticker, \(.ticker){
    get_fii_earnings(
      filter = .ticker,
      start = "2024-09-01",
      end = "2025-10-31"
    ) |> 
      select(-ticker)
  }, .progress = T)) |> 
  unnest(proventos) |>
  distinct()

# test da funcao ntile
proventos |> 
  filter(year(baseDate)==2025, month(baseDate)==9) |>
  mutate(q = as.factor(ntile(dividendYield,5))) |> 
  ggplot(aes(x=dividendYield, group=q, fill=q)) +
  geom_histogram() +
  theme_light()

# last month
dy_lm <- proventos |> 
  filter(year(baseDate)==2025, month(baseDate)==9) |>
  distinct() |> 
  mutate(dyq_lm = ntile(dividendYield,5)) |> 
  select(ticker, dy=dividendYield, dyq_lm)
  
dy_l3m <- proventos |> 
  filter(baseDate >= ymd(20250701), 
         baseDate < ymd(20251001)) |> 
  distinct() |> 
  summarise(dy3m = mean(dividendYield, na_rm=T),
            .by=ticker) |> 
  mutate(dyq_l3m=ntile(dy3m,5))

dy_l6m <- proventos |> 
  filter(baseDate >= ymd(20250401), 
         baseDate < ymd(20251001)) |> 
  distinct() |> 
  summarise(dy6m = mean(dividendYield, na_rm=T),
            .by=ticker) |> 
  mutate(dyq_l6m=ntile(dy6m,5))

dy_l12m <- proventos |> 
  filter(baseDate >= ymd(20241001), 
         baseDate < ymd(20251001)) |> 
  distinct() |> 
  summarise(dy12m = mean(dividendYield, na_rm=T),
            .by=ticker) |> 
  mutate(dyq_l12m=ntile(dy12m,5))

score <- dy_lm |> 
  inner_join(dy_l3m, by = join_by(ticker)) |> 
  inner_join(dy_l6m, by = join_by(ticker)) |> 
  inner_join(dy_l12m, by = join_by(ticker)) |> 
  mutate( score = dyq_lm + dyq_l3m + dyq_l6m + dyq_l12m) 

score |> 
  filter(score==4) |> 
  arrange(dy, dy3m, dy6m, dy12m) 
  
l12m <- proventos |> 
  summarise(
    avgRent = mean(dividendYield, na_rm=T),
    sdRent  = sd(dividendYield),
    .by = ticker
  ) |>
  filter( !ticker %in% c("HGPO11", "RBED11"))

l12m |> 
  ggplot(aes(x=sdRent, y=avgRent)) +
  geom_point() +
  geom_text_repel(aes(label=ticker)) +
  geom_vline(xintercept = mean(l12m$sdRent), linetype="dashed", color="grey") +
  geom_hline(yintercept = mean(l12m$avgRent), linetype="dashed", color="grey") +
  theme_light()

proventos |> 
  filter(ticker=="RBED11")

siBA <- statusinvestBuscaAvancadaFIIs_importer()


sidy <- siBA |> 
  mutate(ldy=100*ultimo_dividendo/preco) |> 
  select(ticker, preco, ultimo_dividendo, ldy, dy, p_vp)

portCons |> 
  distinct(ticker) |> 
  inner_join(sidy, by = join_by(ticker)) |> 
  arrange(dy, ldy) |> 
  View()

portCons |> 
  filter(ticker=="RBED11")

