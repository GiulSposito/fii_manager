# importacoes

source("./R/import/portfolioGoogleSheets.R") # carteira de fundos
source("./R/import/pricesYahoo.R")           # cotacoes da carteira

# scrapping dos proventos das carteiras
source("./R/import/proventos.R")             
proventos <- updateProventos(portfolio)

# corrige proventos problematicos
