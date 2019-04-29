# importacoes
source("./R/import/portfolioGoogleSheets.R") # carteira de fundos
source("./R/import/pricesYahoo.R")           # cotacoes da carteira

# import (update) portifolio e tickers price
port  <- updatePortfolio()
price <- updatePortfolioPrices(port)

# importa proventos e corrige (splits e corrections)
source("./R/import/proventos.R")
source("./R/import/fixProventos.R")
proventos  <- importProventos(port$ticker)
prov.fixed <- fixProventos(proventos)
prov       <- updateProventos(prov.fixed)

