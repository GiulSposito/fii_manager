# importacoes
source("./R/import/portfolioGoogleSheets.R") # carteira de fundos
source("./R/import/pricesYahoo.R")           # cotacoes da carteira

# import (update) portifolio e tickers price
portfolio <- updatePortfolio()
price     <- updatePortfolioPrices(portfolio)


# scrapping dos proventos das carteiras
source("./R/import/proventos.R")             
proventos <- updateProventos(portfolio)

# corrige proventos problematicos
