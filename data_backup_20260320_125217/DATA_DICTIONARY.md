# Dicionário de Dados - FII Manager

**Gerado em**: 2026-03-20 12:33:40
---

## Visão Geral do Modelo de Dados

O sistema FII Manager utiliza arquivos RDS (formato nativo do R) para armazenar dados localmente. Os dados são organizados em diferentes arquivos especializados:

1. **portfolio.rds** - Posições da carteira de investimentos
2. **quotations.rds** - Cotações históricas dos FIIs
3. **income.rds** - Distribuições de rendimentos (proventos)
4. **fii_lupa.rds** - Dados de mercado da Lupa de FIIs
5. **fii_info.rds** - Informações cadastrais dos FIIs
6. **fiis.rds** - Lista consolidada de FIIs

### Relacionamentos

Os arquivos se relacionam através do campo **ticker** (código do FII), que serve como chave primária para junção entre os diferentes datasets.

```
portfolio ─┐
           ├─[ticker]─> quotations
           ├─[ticker]─> income
           ├─[ticker]─> fii_lupa
           └─[ticker]─> fii_info
```

---

## Detalhamento dos Arquivos

### fii_info.rds

- **Tipo**: tbl_df, tbl, data.frame
- **Registros**: 352
- **Colunas**: 4

#### Estrutura de Dados

| Campo | Tipo | Únicos | NAs | % NA | Exemplo |
|-------|------|--------|-----|------|----------|
| ticker | character | 352 | 0 | 0% | ABCP11 |
| price | list | 352 | 0 | 0% | <lista> |
| updates | list | 352 | 0 | 0% | <lista> |
| proventos | list | 312 | 0 | 0% | <lista> |

### fii_lupa.rds

- **Tipo**: list
- **Elementos**: 2

### fiis.rds

- **Tipo**: tbl_df, tbl, data.frame
- **Registros**: 538
- **Colunas**: 22

#### Estrutura de Dados

| Campo | Tipo | Únicos | NAs | % NA | Exemplo |
|-------|------|--------|-----|------|----------|
| post_title | character | 538 | 0 | 0% | DMAC11 |
| id | integer | 538 | 0 | 0% | 13,911,418.00 |
| post_id | integer | 538 | 0 | 0% | 350,089.00 |
| ticker | character | 538 | 0 | 0% | DMAC11 |
| rendimento | numeric | 282 | 0 | 0% | 4.89 |
| dy | numeric | 147 | 0 | 0% | 0.0000 |
| data_pagamento | Date | 164 | 0 | 0% | 2021-12-22 |
| data_base | Date | 155 | 0 | 0% | 2021-12-15 |
| rendimento_12m | numeric | 500 | 0 | 0% | 15.10 |
| rendimento_12m_porcen | numeric | 380 | 0 | 0% | 0.0000 |
| patrimonio_cota | numeric | 440 | 0 | 0% | 63.81 |
| cota_base | numeric | 372 | 0 | 0% | 0.0000 |
| last_dividend | logical | 1 | 0 | 0% | TRUE |
| tipo | character | 1 | 0 | 0% | Rendimento |
| tipo_fii | character | 29 | 0 | 0% | Tijolo:Fundo de Desenvolvimento |
| publicoalvo | character | 5 | 0 | 0% | Investidores em Geral |
| administrador | character | 39 | 0 | 0% | BANCO DAYCOVAL S.A. |
| cota_vp | numeric | 463 | 0 | 0% | 0.2037 |
| negocios | integer | 1 | 538 | 100% | NA |
| participacao_ifix | numeric | 145 | 174 | 32.34% | 0.0760 |
| numero_cotista | integer | 422 | 0 | 0% | 8,102.00 |
| patrimonio | numeric | 465 | 0 | 0% | 118,155,565.38 |

### income.rds

- **Tipo**: tbl_df, tbl, data.frame
- **Registros**: 25,215
- **Colunas**: 6

#### Estrutura de Dados

| Campo | Tipo | Únicos | NAs | % NA | Exemplo |
|-------|------|--------|-----|------|----------|
| ticker | character | 464 | 0 | 0% | AAGR11 |
| rendimento | numeric | 5,442 | 0 | 0% | 1.17 |
| data_base | Date | 1,854 | 0 | 0% | 2025-01-08 |
| data_pagamento | Date | 1,901 | 0 | 0% | 2024-01-15 |
| cota_base | numeric | 7,826 | 0 | 0% | 86.90 |
| dy | numeric | 856 | 0 | 0% | 1.34 |

### portfolio.rds

- **Tipo**: tbl_df, tbl, data.frame
- **Registros**: 142
- **Colunas**: 7

#### Estrutura de Dados

| Campo | Tipo | Únicos | NAs | % NA | Exemplo |
|-------|------|--------|-----|------|----------|
| date | POSIXct, POSIXt | 106 | 0 | 0% | 2017-07-25 |
| ticker | character | 60 | 0 | 0% | BRCR11 |
| volume | numeric | 55 | 0 | 0% | 23.00 |
| price | numeric | 132 | 0 | 0% | 91.20 |
| taxes | numeric | 82 | 0 | 0% | 10.67 |
| value | numeric | 142 | 0 | 0% | 2,108.27 |
| portfolio | character | 3 | 0 | 0% | Empiricus |

### quotations.rds

- **Tipo**: tbl_df, tbl, data.frame
- **Registros**: 358,444
- **Colunas**: 3

#### Estrutura de Dados

| Campo | Tipo | Únicos | NAs | % NA | Exemplo |
|-------|------|--------|-----|------|----------|
| ticker | character | 443 | 0 | 0% | AAGR11 |
| price | numeric | 27,230 | 0 | 0% | 80.24 |
| date | POSIXct, POSIXt | 1,451 | 0 | 0% | 2024-02-21 |

---

## Convenções de Dados

### Formatos

- **Datas**: Armazenadas como objetos `Date` do R (formato ISO: YYYY-MM-DD)
- **Valores Monetários**: Numéricos (double), em Reais (BRL)
- **Tickers**: Strings uppercase (ex: "HGLG11", "KNRI11")
- **Percentuais**: Numéricos em formato decimal (ex: 0.0523 = 5.23%)

### Padrões de Nomenclatura

- `ticker` - Código do FII
- `date` / `data.*` - Campos de data
- `value` / `valor` - Valores monetários
- `price` / `preco` - Preços/cotações
- `volume` / `qtd` - Quantidades
- `rendimento` / `yield` - Rendimentos/dividendos

### Dados Faltantes

- Valores ausentes são representados como `NA` (padrão R)
- Campos com alta % de NAs podem indicar dados opcionais ou não disponíveis para todos os FIIs

---

## Notas de Atualização

- Os dados são atualizados através dos pipelines em `R/pipeline/`
- Proventos são incrementais e podem conter correções históricas
- Cotações são importadas do Yahoo Finance com sufixo `.SA`
- Dados da Lupa de FIIs são obtidos via API com autenticação CSRF


