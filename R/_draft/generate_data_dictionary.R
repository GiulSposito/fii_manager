library(tidyverse)
library(glue)

# Função para analisar estrutura de um arquivo RDS
analyze_rds <- function(file_path) {
  data <- readRDS(file_path)

  # Informações básicas
  info <- list(
    file_name = basename(file_path),
    class = class(data),
    n_rows = if(is.data.frame(data)) nrow(data) else NA,
    n_cols = if(is.data.frame(data)) ncol(data) else length(data)
  )

  # Se for data frame ou tibble, analisa as colunas
  if(is.data.frame(data)) {
    cols_info <- tibble(
      column = names(data),
      type = sapply(data, function(x) paste(class(x), collapse = ", ")),
      n_unique = sapply(data, function(x) length(unique(x))),
      n_na = sapply(data, function(x) sum(is.na(x))),
      pct_na = sapply(data, function(x) round(100 * sum(is.na(x)) / length(x), 2)),
      example = sapply(data, function(x) {
        if(is.list(x)) {
          return("<lista>")
        }
        val <- head(na.omit(x), 1)
        if(length(val) > 0) {
          # Formatar melhor os valores de exemplo
          if(inherits(val, "Date")) {
            format(val, "%Y-%m-%d")
          } else if(is.numeric(val)) {
            if(abs(val) < 1) {
              sprintf("%.4f", val)
            } else {
              format(round(val, 2), big.mark=",", nsmall=2)
            }
          } else {
            str_trunc(as.character(val), 50)
          }
        } else "NA"
      })
    )

    info$columns <- cols_info
  }

  return(info)
}

# Analisar todos os arquivos RDS
data_files <- list.files("./data", pattern = "\\.rds$", full.names = TRUE)

analyses <- map(data_files, analyze_rds)
names(analyses) <- basename(data_files)

# Função para gerar markdown para cada arquivo
generate_file_md <- function(analysis) {
  md <- glue("### {analysis$file_name}\n\n")
  md <- paste0(md, glue("- **Tipo**: {paste(analysis$class, collapse = ', ')}\n"))

  if(!is.na(analysis$n_rows)) {
    md <- paste0(md, glue("- **Registros**: {format(analysis$n_rows, big.mark=',')}\n"))
    md <- paste0(md, glue("- **Colunas**: {analysis$n_cols}\n"))
    md <- paste0(md, "\n")

    if(!is.null(analysis$columns)) {
      md <- paste0(md, "#### Estrutura de Dados\n\n")
      md <- paste0(md, "| Campo | Tipo | Únicos | NAs | % NA | Exemplo |\n")
      md <- paste0(md, "|-------|------|--------|-----|------|----------|\n")

      for(i in 1:nrow(analysis$columns)) {
        row <- analysis$columns[i,]
        md <- paste0(md, glue("| {row$column} | {row$type} | {format(row$n_unique, big.mark=',')} | {row$n_na} | {row$pct_na}% | {row$example} |\n"))
      }
      md <- paste0(md, "\n")
    }
  } else {
    md <- paste0(md, glue("- **Elementos**: {analysis$n_cols}\n"))
    md <- paste0(md, "\n")
  }

  return(md)
}

# Gerar documento completo
doc <- "# Dicionário de Dados - FII Manager\n\n"
doc <- paste0(doc, glue("**Gerado em**: {format(Sys.time(), '%Y-%m-%d %H:%M:%S')}\n\n"))
doc <- paste0(doc, "---\n\n")

doc <- paste0(doc, "## Visão Geral do Modelo de Dados\n\n")
doc <- paste0(doc, "O sistema FII Manager utiliza arquivos RDS (formato nativo do R) para armazenar dados localmente. ")
doc <- paste0(doc, "Os dados são organizados em diferentes arquivos especializados:\n\n")

doc <- paste0(doc, "1. **portfolio.rds** - Posições da carteira de investimentos\n")
doc <- paste0(doc, "2. **quotations.rds** - Cotações históricas dos FIIs\n")
doc <- paste0(doc, "3. **income.rds** - Distribuições de rendimentos (proventos)\n")
doc <- paste0(doc, "4. **fii_lupa.rds** - Dados de mercado da Lupa de FIIs\n")
doc <- paste0(doc, "5. **fii_info.rds** - Informações cadastrais dos FIIs\n")
doc <- paste0(doc, "6. **fiis.rds** - Lista consolidada de FIIs\n\n")

doc <- paste0(doc, "### Relacionamentos\n\n")
doc <- paste0(doc, "Os arquivos se relacionam através do campo **ticker** (código do FII), que serve como chave primária ")
doc <- paste0(doc, "para junção entre os diferentes datasets.\n\n")

doc <- paste0(doc, "```\n")
doc <- paste0(doc, "portfolio ─┐\n")
doc <- paste0(doc, "           ├─[ticker]─> quotations\n")
doc <- paste0(doc, "           ├─[ticker]─> income\n")
doc <- paste0(doc, "           ├─[ticker]─> fii_lupa\n")
doc <- paste0(doc, "           └─[ticker]─> fii_info\n")
doc <- paste0(doc, "```\n\n")

doc <- paste0(doc, "---\n\n")
doc <- paste0(doc, "## Detalhamento dos Arquivos\n\n")

# Adicionar análise de cada arquivo
for(file_name in names(analyses)) {
  doc <- paste0(doc, generate_file_md(analyses[[file_name]]))
}

doc <- paste0(doc, "---\n\n")
doc <- paste0(doc, "## Convenções de Dados\n\n")
doc <- paste0(doc, "### Formatos\n\n")
doc <- paste0(doc, "- **Datas**: Armazenadas como objetos `Date` do R (formato ISO: YYYY-MM-DD)\n")
doc <- paste0(doc, "- **Valores Monetários**: Numéricos (double), em Reais (BRL)\n")
doc <- paste0(doc, "- **Tickers**: Strings uppercase (ex: \"HGLG11\", \"KNRI11\")\n")
doc <- paste0(doc, "- **Percentuais**: Numéricos em formato decimal (ex: 0.0523 = 5.23%)\n\n")

doc <- paste0(doc, "### Padrões de Nomenclatura\n\n")
doc <- paste0(doc, "- `ticker` - Código do FII\n")
doc <- paste0(doc, "- `date` / `data.*` - Campos de data\n")
doc <- paste0(doc, "- `value` / `valor` - Valores monetários\n")
doc <- paste0(doc, "- `price` / `preco` - Preços/cotações\n")
doc <- paste0(doc, "- `volume` / `qtd` - Quantidades\n")
doc <- paste0(doc, "- `rendimento` / `yield` - Rendimentos/dividendos\n\n")

doc <- paste0(doc, "### Dados Faltantes\n\n")
doc <- paste0(doc, "- Valores ausentes são representados como `NA` (padrão R)\n")
doc <- paste0(doc, "- Campos com alta % de NAs podem indicar dados opcionais ou não disponíveis para todos os FIIs\n\n")

doc <- paste0(doc, "---\n\n")
doc <- paste0(doc, "## Notas de Atualização\n\n")
doc <- paste0(doc, "- Os dados são atualizados através dos pipelines em `R/pipeline/`\n")
doc <- paste0(doc, "- Proventos são incrementais e podem conter correções históricas\n")
doc <- paste0(doc, "- Cotações são importadas do Yahoo Finance com sufixo `.SA`\n")
doc <- paste0(doc, "- Dados da Lupa de FIIs são obtidos via API com autenticação CSRF\n\n")

# Salvar o documento
writeLines(doc, "./data/DATA_DICTIONARY.md")

cat("✓ Dicionário de dados gerado em: ./data/DATA_DICTIONARY.md\n")
cat(glue("✓ Analisados {length(analyses)} arquivos RDS\n"))
