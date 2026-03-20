library(tidyverse)

fiis <- readRDS("./data/fiis.rds")
port <- readRDS("./data/portfolio.rds")
quot <- readRDS("./data/quotations.rds")
inc  <- readRDS("./data/income.rds")

emp_raw <- read_file("./data/carteira_empiricus.txt")

emp_tickers <- emp_raw |> 
  str_extract_all("[A-Z]{4}11") |> 
  unlist()


# o que do meu portfolio vale a pena vender?

# criterios:
# 1. o valor do dividendo nao compensa o valor atual investido

# capital investido em cotas
carteira <- port |> 
  summarise(volume = sum(volume), .by = ticker) |> 
  mutate(volume=case_when(
    ticker=="MGFF11" ~ 0,
    ticker=="RECR11" ~ volume/2,
    T ~ volume
  ))

carteira <- quot |> 
  filter(date==max(date), .by = ticker) |> 
  inner_join(carteira, by=join_by(ticker)) |> 
  mutate(capital=volume*price)
  
carteira <- inc |>
  filter(data_base == max(data_base), 
         data_base >= ymd(20240101), 
         .by = ticker) |>
  # summarise(provento_medio = mean(rendimento), .by=ticker) |>
  inner_join(carteira, by = join_by(ticker)) |>
  mutate(rend_total = volume * rendimento) |>
  mutate(taxa_roi = rend_total / capital) |>
  mutate(recomendado = ticker %in% emp_tickers) |> 
  filter(!is.nan(taxa_roi)) |>
  arrange(taxa_roi) |>
  inner_join(
    select(
      fiis,
      ticker,
      rendimento_12m_porcen,
      patrimonio_cota,
      cota_base,
      cota_vp
    ),
    by = join_by(ticker)
  )

g <- carteira |> 
  ggplot(aes(x=cota_vp, y=taxa_roi, size=capital, color=rendimento_12m_porcen, text=ticker, shape=recomendado)) +
  geom_point() +
  geom_vline(xintercept = 1, lty="dashed") +
  geom_hline(yintercept = 0.007, lty="dashed") +
  scale_color_gradient2(low="red", mid="orange", high = "blue", midpoint = 0.75) +
  theme_light()

plotly::ggplotly(g)

carteira |> 
  filter(cota_vp>=.95, taxa_roi<=.007)



Rent_Real = ((1+rent_nominal)/(1+taxa_inf))-1
((1+0.8)/(1+0.37))-1




