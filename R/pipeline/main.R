# importacoes
source("./R/import/portfolioGoogleSheets.R") # carteira de fundos
port  <- updatePortfolio()

# import (update) portifolio e tickers price
source("./R/import/pricesYahoo.R")           # cotacoes da carteira
price <- updatePortfolioPrices(port)

# importa proventos e corrige (splits e corrections)
source("./R/import/proventos.R")
proventos_page <- scrapProventos(port$ticker)
# we think that we need to close the connections here to process the pages
gc() 
Sys.sleep(180)
proventos      <- extractProvFromScrap(proventos_page)

source("./R/import/fixProventos.R")
prov.fixed     <- fixProventos(proventos)
prov           <- updateProventos(prov.fixed)

