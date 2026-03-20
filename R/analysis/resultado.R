library(tidyverse)

fiis <- readRDS("./data/fiis.rds")
port <- readRDS("./data/portfolio.rds")
quot <- readRDS("./data/quotations.rds")
inc  <- readRDS("./data/income.rds")

port |> 
  inner_join(quot, by="ticker")

# ganho de capital
# 
# para cada linha no portfolio
# Investido = valor da linha (port)
# Capital = Numero de cotas (port) * valor atual da cota (quot)
# Ganho = Capital-investido

# total de valor pago pelo investimento
#
# para cada ticker do port
# inner join com dividendos (inc)
# filter inc > data de inicio
# valor = cotas


# tickers/operacoes encerradas
#
# Operacoes ativas cuja a ultima cotação não é deste ano
tickers_inativos <- quot |> 
  filter(date==max(date), .by="ticker") |> # ultimas operacoes por ticker
  filter(date<=ymd("20240101"))            # ticker inativos em 2024
  
port |>
  rename(price_ini=price, capital_ini=value, date_open=date) |> 
  select(-portfolio) |> 
  inner_join(tickers_inativos, by = join_by(ticker))

## Tickers que sumiram

# MGFF11 => VGHF11
# VGHF11 comprou MGFF11
# Encerrar a operação do MGFF11 (last quote?)
# Criar uma operação VGHF11 (init quote?)

# SDIL11 => TRBL11
# SDIL11 trocou de nome
# Encerrar e Abrir outra
# Manter dinâmico ou martelar?

# VLOL11 => PVBI11
# PVBI11 comprou VLOL11
# Encerrar a operação do VLOL11 (last quote?)
# Criar uma operação PVBI11 (init quote?)

## tickers splitados
library(mcp)

regr_data <- port |> 
  distinct(ticker) |> 
  inner_join(quot, by = join_by(ticker)) |> 
  filter(ticker=="HGRE11") |> 
  mutate(date = as.integer(date)/100)

models <- list(price ~ 1 + date, ~ 1 + date)
fit_mcp <- mcp(models, data=regr_data, par_x = "date")


port |> 
  rename(initial_captial=value)


quot |> 
  filter(date==max(date), .by=ticker) |> # ultima cotacao por ticker
  filter(date>=ydm("20240101")) |>       # tickers que tem cotacao em 2024 (ativos)
  select(ticker, last_price=price) |>    
  inner_join(port, by = join_by(ticker)) |> 
  rename(init_price=price, init_capital=value) |> 
  mutate(curr_capital=volume*last_price) |> 
  mutate(capital_gain=(curr_capital-init_capital)/init_capital) |> 
  select(ticker, init_price, last_price, capital_gain) |> 
  arrange(desc(capital_gain)) |> 
  View()

