library(pdftools)
library(tidyverse)
library(janitor)

importNuInfRendFii <- function(arquivo =  "./import/irpf2024_nubank.pdf", pages = 5:6) {
  # Extrai o texto por página (cada elemento do vetor é uma página)
  texto_paginas <- pdf_text(arquivo)
  pages |>
    map_df(function(page) {
      tibble(text = texto_paginas[[page]]) |>
        str_extract_all("([A-Z]{4}\\d{2})\\s+(\\d+)\\s+(\\d+)", simplify = F) |>
        unlist() |>
        as_tibble_col(column_name = "text") |>
        separate(text, into = c("ticker", "cotas2023", "cotas2024")) |>
        mutate(across(cotas2023:cotas2024, as.integer))
    }) |>
    distinct()
}    