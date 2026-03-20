library(tidyverse)
library(readxl)

importXpiPosConsFii <- function(arquivo = "./import/PosicaoDetalhada (1).xlsx", 
                                range = "A17:H62") {
  dados <- read_excel(arquivo, range = range)
  dados |>
    set_names(
      c(
        "ticker",
        "posicao",
        "alocação",
        "rent_c_prov",
        "rent_bruta",
        "price_avg",
        "last_price",
        "qtd"
      )
    ) |>
    mutate(across(posicao:last_price, 
                  \(x) parse_number(x, na = c("-", "Indefinido"))), 
           qtd = parse_integer(qtd)) |>
    distinct()
}  