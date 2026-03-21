source("./R/import/portfolioGoogleSheets.R")
source("./R/api/fii_incomes.R")
source("./R/api/fii_quotations.R")
source("./R/api/import_lupa_2023.R")

# pega o portfolio do google drive
port <- updatePortfolio()
fiis <- importLupa()

fii_list <- fiis |> 
  filter(data_pagamento>=ymd("2024-01-01")) |> 
  distinct(ticker) |> 
  arrange(ticker)

safeGetIncome <- safely(getIncomes)

resp_income <- fii_list |> 
  mutate( income_call = map(ticker, safeGetIncome, .progress=T)) |> 
  mutate( income = map(income_call, function(.x) .x$result ) )
  
income <- resp_income |> 
  select(ticker, income) |> 
  unnest(income)

safeGetQuotations <- safely(getQuotations)

resp_quotation <- fii_list |> 
  mutate( quotation_call = map(ticker,safeGetQuotations, .progress = T)) |> 
  mutate( quotation = map(quotation_call, function(.x) .x$result ) )

quotations <- resp_quotation |> 
  select(ticker, quotation) |> 
  unnest(quotation)


saveRDS(fiis,"./data/fiis.rds")
saveRDS(income, "./data/income.rds")
saveRDS(quotations, "./data/quotations.rds")
saveRDS(port, "./data/portfolio.rds")
