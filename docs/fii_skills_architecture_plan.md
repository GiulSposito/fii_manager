# Plano de Arquitetura: Skills para Análise de FII

**Data:** 2026-03-20
**Status:** Planejamento (não implementado)

## 1. Filosofia da Abordagem

**Nem tudo deve ser skill.** A melhor arquitetura combina:

- **Skills** → Automações de **fluxo de trabalho** (workflows repetitivos, decisões contextuais)
- **Memória** → Conhecimento **declarativo** (indicadores, thresholds, padrões)
- **Código R** → Lógica de **negócio e cálculo** (funções, pipelines)
- **Documentação** → Referências **estáticas** (como o knowledge_base_refs.md atual)

## 2. Proposta de Skills (4 skills principais)

### **Skill 1: `fii-analysis`**
**Propósito:** Workflow completo de análise de um FII individual

**Gatilhos:**
- "analisar FII XPTO11"
- "análise completa de HGLG11"
- "avaliar fundo MXRF11"

**Ações:**
1. Identifica tipo do FII (tijolo/papel/FOF/híbrido)
2. Coleta dados das fontes primárias (CVM, B3) e secundárias (Status Invest, Funds Explorer)
3. Calcula indicadores-chave relevantes para o tipo
4. Executa o framework de 4 blocos (qualidade, renda, valuation, risco)
5. Gera score final e relatório de recomendação
6. Compara com pares do mesmo segmento

**Output:** Relatório markdown + visualizações + decisão (comprar/vender/manter)

---

### **Skill 2: `fii-portfolio-rebalance`**
**Propósito:** Avaliação de necessidade de rebalanceamento da carteira

**Gatilhos:**
- "rebalancear carteira"
- "avaliar rebalanceamento"
- "sugerir ajustes no portfolio"

**Ações:**
1. Carrega portfolio atual (Google Sheets → portfolio.rds)
2. Verifica limites: por fundo (5-12%), por gestor, por segmento, por indexador
3. Calcula exposições: macro (juros/inflação), setorial, geográfica
4. Identifica desvios das bandas de rebalanceamento
5. Sugere ordens de compra/venda respeitando restrições
6. Simula impacto fiscal e custos de transação

**Output:** Lista de ordens sugeridas + justificativa + impacto esperado

---

### **Skill 3: `fii-data-quality`**
**Propósito:** Validação de qualidade e consistência de dados de FII

**Gatilhos:**
- "validar dados de FII"
- "checar consistência dos proventos"
- "detectar anomalias em cotações"

**Ações:**
1. Valida consistência entre fontes (Yahoo vs B3 vs Status Invest)
2. Detecta outliers em: cotações, dividend yield, P/VP, vacância
3. Identifica splits/desdobramentos não tratados
4. Checa missing data e gaps temporais
5. Valida formato de tickers e nomes
6. Cruza proventos declarados com distribuições efetivas

**Output:** Relatório de anomalias + script de correções sugeridas

---

### **Skill 4: `fii-score`**
**Propósito:** Cálculo do score multifatorial para FII (implementação do framework quantitativo)

**Gatilhos:**
- "calcular score de HGLG11"
- "ranking de FIIs por score"
- "comparar scores de papel"

**Ações:**
1. Coleta dados necessários para os 4 blocos:
   - Bloco A (Qualidade): vacância, concentração, prazo, inadimplência, alavancagem
   - Bloco B (Renda): DY 12M, estabilidade, payout, cobertura
   - Bloco C (Valuation): P/VP, desconto vs pares, yield spread
   - Bloco D (Risco): liquidez, volatilidade, drawdown, correlações
2. Normaliza métricas por z-score dentro do segmento
3. Aplica ponderações configuráveis
4. Gera score agregado (0-100)
5. Posiciona no ranking do segmento

**Output:** Score detalhado por bloco + posição no ranking + gráfico radar

---

## 3. O que NÃO deve ser skill

### **Memória (`~/.claude/memory/`)** ← Melhor para:

```
fii-indicators.md:
- Indicadores por tipo (tijolo: vacância, prazo contratual / papel: duration, LTV)
- Thresholds de alerta (vacância > 15%, concentração > 30%)
- Fórmulas de cálculo (P/VP, DY, cap rate)

fii-sources.md:
- URLs das APIs (CVM, B3, Lupa de FIIs)
- Tokens/autenticação (se aplicável)
- Mapeamento de campos entre fontes

fii-preferences.md:
- Perfil de risco do usuário
- Limites de alocação padrão
- Segmentos preferidos
```

### **Código R (`R/`)** ← Melhor para:

```
R/analysis/fii_score.R           # Funções de cálculo do score
R/analysis/fii_indicators.R      # Cálculos de indicadores individuais
R/analysis/fii_comparison.R      # Comparação entre pares
R/import/fii_cvm_data.R          # Importador de dados CVM estruturados
R/transform/fii_normalize.R      # Normalização e padronização
```

### **Documentação (`docs/`)** ← Melhor para:

```
docs/knoledge_base_refs.md       # O que já existe (referências teóricas)
docs/data_dictionary.md          # Dicionário de campos (já existe!)
docs/fii_methodology.md          # Metodologia detalhada de análise (novo)
docs/fii_segmentation.md         # Taxonomia de tipos de FII (novo)
```

---

## 4. Integração entre Componentes

```
┌─────────────────┐
│  Usuário pede   │
│ "analisar HGLG11"│
└────────┬────────┘
         │
         ▼
   ┌────────────┐
   │  /fii-analysis  │◄─────── SKILL (workflow)
   └────┬───────┘
        │
        ├─── lê → MEMÓRIA (fii-indicators.md) ← indicadores relevantes
        │
        ├─── chama → CÓDIGO R (fii_score.R) ← cálculos pesados
        │
        ├─── consulta → DOCS (knowledge_base_refs.md) ← contexto teórico
        │
        └─── usa → APIs externas (CVM, B3, Status Invest)
                   ▲
                   └─────── URLs em MEMÓRIA (fii-sources.md)
```

---

## 5. Ordem de Implementação Sugerida

### **Fase 1: Fundação (sem skills ainda)**
1. Reorganizar conhecimento declarativo → **memory/fii-indicators.md**
2. Extrair fontes de dados → **memory/fii-sources.md**
3. Criar funções R core → **R/analysis/fii_score.R**
4. Documentar metodologia → **docs/fii_methodology.md**

### **Fase 2: Skill Core**
5. Criar `/fii-score` (skill mais isolado, sem dependências externas complexas)
6. Testar e validar com 3-5 FIIs de tipos diferentes

### **Fase 3: Skills de Workflow**
7. Criar `/fii-analysis` (usa fii-score internamente)
8. Criar `/fii-data-quality`

### **Fase 4: Skills Avançados**
9. Criar `/fii-portfolio-rebalance` (depende de analysis + score)

---

## 6. Exemplo Conceitual: Skill `/fii-analysis`

```yaml
# Metadados do skill (o que o skillMaker geraria)
name: fii-analysis
description: "Análise completa de um FII individual com framework de 4 blocos"
triggers:
  - "analisar FII {ticker}"
  - "análise completa de {ticker}"
  - "avaliar fundo {ticker}"

inputs:
  ticker:
    type: string
    pattern: "[A-Z]{4}11"
    required: true
    description: "Ticker do FII (ex: HGLG11)"

workflow:
  1_identify_type:
    prompt: "Identifique o tipo do FII {ticker} consultando dados da CVM/B3"
    output: fii_type  # tijolo | papel | fof | hibrido

  2_collect_data:
    prompt: |
      Colete dados de {ticker} de:
      - CVM (informe mensal estruturado)
      - B3 (cotações e liquidez)
      - Status Invest (indicadores calculados)
      - Funds Explorer (comparação com pares)
    memory_reference: "fii-sources.md"  # URLs das fontes

  3_calculate_indicators:
    call_r_function: "fii_score.R::calculate_full_score"
    args:
      ticker: "{ticker}"
      type: "{fii_type}"
    output: score_data

  4_generate_report:
    prompt: |
      Gere relatório de análise com:
      - Score final: {score_data.total}
      - Breakdown por bloco (qualidade/renda/valuation/risco)
      - Comparação com mediana do segmento
      - Recomendação (comprar/vender/manter)
      - Justificativa baseada nos indicadores críticos
    memory_reference: "fii-indicators.md"  # Thresholds e interpretação
    output_format: markdown
```

---

## 7. Considerações Finais

### **Vantagens da Abordagem Híbrida:**
- **Skills** ficam focados e rápidos (não carregados de conhecimento estático)
- **Memória** é consultável em qualquer contexto (não apenas dentro do skill)
- **Código R** fica testável e versionável independentemente
- **Documentação** serve tanto para Claude quanto para humanos

### **Quantos skills total?**
**4 skills principais** (análise, rebalance, data-quality, score)

Mais tarde, se fizer sentido:
- `/fii-screener` (filtro inicial de FIIs por critérios)
- `/fii-report` (gera relatório mensal automático)
- `/fii-alert` (monitora thresholds e avisa)

### **Decisão-chave:**
O `knowledge_base_refs.md` **não deve ser transformado em skill**, mas sim:
1. Parte dele vai para **memory/** (indicadores, thresholds)
2. Parte fica como **documentação** (framework teórico, referências acadêmicas)
3. Os **workflows práticos** viram skills que **consultam** esse conhecimento

---

## 8. Skills Futuros (Expansão)

### **Skill 5: `fii-screener`** (opcional)
**Propósito:** Filtro inicial de universo de FIIs por múltiplos critérios

**Gatilhos:**
- "buscar FIIs de shopping com DY > 10%"
- "filtrar FIIs de papel high grade"
- "screener de logística com vacância < 5%"

**Ações:**
1. Carrega universo de FIIs ativos (B3)
2. Aplica filtros compostos por tipo, indicadores, liquidez
3. Ordena por critério escolhido
4. Retorna top N candidatos para análise detalhada

---

### **Skill 6: `fii-report`** (opcional)
**Propósito:** Relatório mensal automático da carteira

**Gatilhos:**
- "gerar relatório mensal"
- "resumo do mês de fevereiro"
- "report mensal de performance"

**Ações:**
1. Coleta dados de performance do mês
2. Calcula retorno total (cotação + proventos)
3. Compara com IFIX e CDI
4. Identifica maiores contribuidores/detratores
5. Lista eventos relevantes (proventos, fatos relevantes)
6. Gera dashboard em HTML

---

### **Skill 7: `fii-alert`** (opcional)
**Propósito:** Monitoramento e alertas de thresholds

**Gatilhos:**
- "configurar alertas de vacância"
- "avisar quando P/VP < 0.9"
- "monitorar inadimplência dos meus FIIs"

**Ações:**
1. Configura regras de alerta personalizadas
2. Monitora indicadores periodicamente
3. Dispara notificação quando threshold é ultrapassado
4. Sugere ação (revisitar análise, considerar venda, etc.)

**Nota:** Requer infraestrutura de scheduling (cron jobs ou similar)

---

## 9. Métricas de Sucesso

Para avaliar se os skills estão funcionando bem:

1. **Tempo de execução** < 3 minutos para fii-analysis completo
2. **Cobertura de dados** > 90% dos indicadores populados
3. **Acurácia** das classificações de tipo (manual validation)
4. **Usabilidade** - usuário consegue iterar sem precisar de troubleshooting
5. **Manutenibilidade** - atualizar thresholds em memória é suficiente, sem mudar código do skill

---

## 10. Dependências Técnicas

### **Pacotes R necessários:**
```r
# Já instalados
tidyverse, lubridate, rvest, httr, jsonlite, googlesheets4

# Novos (provavelmente necessários)
httr2          # APIs modernas (CVM dados abertos)
xml2           # Parsing de XMLs (B3)
quantmod       # Cálculos financeiros avançados
PerformanceAnalytics  # Métricas de risco/retorno
```

### **APIs/Fontes de Dados:**
```
CVM Dados Abertos: https://dados.cvm.gov.br/
B3 Market Data: https://www.b3.com.br/
Status Invest: https://statusinvest.com.br/ (scraping)
Funds Explorer: https://www.fundsexplorer.com.br/ (scraping)
Lupa de FIIs: https://fiis.lupatech.com.br/ (API com CSRF token)
```

### **Estrutura de Memória:**
```
~/.claude/projects/<project>/memory/
├── MEMORY.md                    # Índice principal
├── fii-indicators.md            # Indicadores e thresholds
├── fii-sources.md               # URLs e autenticação
├── fii-preferences.md           # Preferências do usuário
└── fii-portfolio-rules.md       # Regras de alocação
```

---

## 11. Integração com Código e Dados Existentes

Esta seção detalha como a arquitetura proposta se integra com os scripts e dados já implementados no projeto.

### **Mapeamento: Arquitetura Existente → Arquitetura Proposta**

#### **A) Dados em `/data/` = Cache Local dos Skills**

Os arquivos `.rds` funcionam como **cache persistente** que os skills consultam e atualizam:

```
data/
├── portfolio.rds        → usado por /fii-portfolio-rebalance
├── income.rds          → usado por /fii-analysis (bloco Renda)
├── quotations.rds      → usado por /fii-score (bloco Valuation)
├── fiis.rds            → usado por todos (lista master de FIIs - dados Lupa)
├── fii_info.rds        → usado por /fii-analysis (metadados)
└── fii_lupa.rds        → usado por /fii-data-quality (validação)
```

**Relação com skills:**
- Skills **leem** esses arquivos como primeira fonte (rápido, local)
- Skills **atualizam** quando necessário (via pipelines existentes)
- Skills **validam** consistência entre fontes (data-quality)

---

#### **B) Scripts Existentes = Building Blocks dos Skills**

##### **`R/pipeline/pipeline2023.R` → Orquestração Base**

**Código atual:**
```r
# Pipeline que atualiza todos os dados base
source("./R/import/portfolioGoogleSheets.R")
source("./R/api/fii_incomes.R")
source("./R/api/fii_quotations.R")
source("./R/api/import_lupa_2023.R")

port <- updatePortfolio()
fiis <- importLupa()
# ... coleta income e quotations via API
# ... salva tudo em data/*.rds
```

**Como skills usam:**
```yaml
# Skill /fii-data-quality usa pipeline2023.R como base

workflow:
  1_update_base_data:
    call_r_script: "R/pipeline/pipeline2023.R"
    description: "Atualiza dados base (portfolio, income, quotations)"

  2_validate_consistency:
    r_function: "R/analysis/fii_data_quality.R::check_consistency"
    inputs:
      - data/income.rds
      - data/quotations.rds
```

**Refatoração sugerida:**
```r
# R/pipeline/update_data.R (wrapper inteligente)

update_all_data <- function(force = FALSE) {
  # Verifica última atualização
  last_update <- file.mtime("data/portfolio.rds")

  if (!force && difftime(Sys.time(), last_update, units = "hours") < 24) {
    message("Dados já atualizados hoje. Use force=TRUE para forçar.")
    return(invisible(NULL))
  }

  # Executa pipeline original
  source("R/pipeline/pipeline2023.R")
  message("Dados atualizados com sucesso!")
}

# Skills chamam: update_all_data(force = FALSE)
```

---

##### **`R/_draft/statusinvest_indicators.R` → Fonte de Dados para Score**

**Código atual:**
```r
# Extrai indicadores do Status Invest via scraping
get_fii_cards <- function(url_or_path) {
  doc <- read_html(url_or_path)
  # ... extrai cards com P/VP, DY, Vacância, etc.
  # retorna tibble com indicadores
}
```

**Como skills usam:**
```r
# R/analysis/fii_score.R (NOVO - consolida múltiplas fontes)

calculate_full_score <- function(ticker) {
  # 1. Indicadores do Status Invest (JÁ EXISTE!)
  source("R/_draft/statusinvest_indicators.R")
  indicators_si <- get_fii_cards(
    glue("https://statusinvest.com.br/fundos-imobiliarios/{ticker}")
  )

  # 2. Proventos do Status Invest (JÁ EXISTE!)
  source("R/_draft/statusinvest_proventos.R")
  proventos_si <- get_fii_earnings(
    filter = ticker,
    start = "2023-01-01",
    end = Sys.Date()
  )

  # 3. Dados CVM (NOVO - a implementar)
  dados_cvm <- get_cvm_informe_mensal(ticker)

  # 4. Cache local (JÁ EXISTE!)
  income_local <- readRDS("data/income.rds") %>%
    filter(ticker == !!ticker)
  quotations_local <- readRDS("data/quotations.rds") %>%
    filter(ticker == !!ticker)

  # 5. Calcula score nos 4 blocos
  score <- calculate_4_blocks(
    indicators_si,
    proventos_si,
    dados_cvm,
    income_local,
    quotations_local
  )

  return(score)
}
```

**Skill `/fii-score` chama:**
```yaml
workflow:
  calculate:
    r_function: "R/analysis/fii_score.R::calculate_full_score"
    args:
      ticker: "{ticker}"
```

---

##### **`R/_draft/statusinvest_proventos.R` → Validação Cruzada**

**Código atual:**
```r
# Coleta proventos via API do Status Invest
get_fii_earnings <- function(filter, start, end) {
  req <- request("https://statusinvest.com.br/fii/getearnings") %>%
    req_url_query(IndiceCode = "ifix", Filter = filter, ...)
  # retorna tibble com histórico de proventos
}
```

**Como skills usam para data quality:**
```r
# R/analysis/fii_data_quality.R (NOVO)

validate_proventos <- function(ticker) {
  # Fonte 1: Lupa (via pipeline)
  proventos_lupa <- readRDS("data/fiis.rds") %>%
    filter(ticker == !!ticker) %>%
    select(ticker, data_pagamento, valor)

  # Fonte 2: Status Invest (script existente)
  source("R/_draft/statusinvest_proventos.R")
  proventos_si <- get_fii_earnings(ticker, "2023-01-01", Sys.Date())

  # Fonte 3: Cache local (pipeline)
  proventos_local <- readRDS("data/income.rds") %>%
    filter(ticker == !!ticker)

  # Compara e detecta divergências
  discrepancies <- compare_sources(
    proventos_lupa,
    proventos_si,
    proventos_local
  )

  return(discrepancies)
}
```

**Skill `/fii-data-quality` usa:**
```yaml
workflow:
  validate_proventos:
    r_function: "R/analysis/fii_data_quality.R::validate_proventos"
    args:
      ticker: "{ticker}"
```

---

### **Fluxo Completo: Skill Chamando Código Existente**

```
┌──────────────────────────────────────────────────────────────┐
│  Usuário: "analisar FII HGLG11"                              │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ /fii-analysis │  ◄── SKILL
                    └───────┬───────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌──────────────┐   ┌──────────────┐
│ 1. DADOS BASE │   │ 2. ENRIQUECE │   │ 3. ANÁLISE   │
└───────┬───────┘   └──────┬───────┘   └──────┬───────┘
        │                  │                   │
        ▼                  ▼                   ▼
```

#### **1. DADOS BASE (EXISTENTES)**
```
source("R/pipeline/pipeline2023.R")
├─ Carrega portfolio.rds
├─ Carrega income.rds
├─ Carrega quotations.rds
└─ Carrega fiis.rds (Lupa)

SE dados estão desatualizados (> 1 dia):
  ├─ updatePortfolio()
  ├─ getIncomes(ticker)
  └─ getQuotations(ticker)
```

#### **2. ENRIQUECE COM INDICADORES (PARCIALMENTE EXISTENTE)**
```
source("R/_draft/statusinvest_indicators.R")
indicators <- get_fii_cards(
  "https://statusinvest.com.br/fundos-imobiliarios/HGLG11"
)
# retorna: P/VP, DY, Vacância, Liquidez, etc.

source("R/_draft/statusinvest_proventos.R")
proventos <- get_fii_earnings("HGLG11", start, end)
# retorna: histórico completo de proventos

NOVO: source("R/import/fii_cvm_data.R")
informe_cvm <- get_cvm_informe_mensal("HGLG11")
# retorna: concentração, prazo contratos, LTV, etc.
```

#### **3. ANÁLISE (NOVO)**
```
source("R/analysis/fii_score.R")
score <- calculate_full_score(
  ticker = "HGLG11",
  indicators = indicators,
  proventos = proventos,
  cvm_data = informe_cvm,
  portfolio = portfolio.rds,
  quotations = quotations.rds
)
# retorna: score de 0-100 com breakdown por bloco

SKILL GERA RELATÓRIO:
├─ Score: 78/100
├─ Qualidade: 85 (vacância baixa, boa diversificação)
├─ Renda: 72 (DY 9.5%, estável)
├─ Valuation: 68 (P/VP 0.95, yield spread +2.1%)
├─ Risco: 88 (alta liquidez, baixa volatilidade)
└─ Recomendação: MANTER (aguardar P/VP < 0.90)
```

---

### **Novos Componentes a Criar**

#### **A) Funções de Score (`R/analysis/`)**

```r
R/analysis/
├── fii_score.R              # NOVO - score multifatorial
│   ├── calculate_full_score()
│   ├── calculate_quality_block()
│   ├── calculate_income_block()
│   ├── calculate_valuation_block()
│   └── calculate_risk_block()
│
├── fii_indicators.R         # NOVO - cálculos intermediários
│   ├── calc_cap_rate()
│   ├── calc_yield_spread()
│   ├── calc_payout_ratio()
│   └── calc_concentration()
│
├── fii_comparison.R         # NOVO - comparação entre pares
│   ├── get_segment_peers()
│   └── rank_by_segment()
│
└── fii_data_quality.R       # NOVO - validação
    ├── validate_proventos()
    ├── detect_outliers()
    └── check_consistency()
```

#### **B) Importador CVM (`R/import/`)**

```r
R/import/
└── fii_cvm_data.R           # NOVO - dados CVM estruturados
    ├── get_cvm_informe_mensal()
    ├── parse_cvm_carteira()
    └── extract_cvm_indicators()
```

#### **C) Memória Claude (`memory/`)**

```
~/.claude/projects/<projeto>/memory/
├── fii-indicators.md        # NOVO - thresholds e fórmulas
├── fii-sources.md           # NOVO - URLs e APIs
└── fii-preferences.md       # NOVO - perfil do usuário
```

---

### **Como Executar: Antes vs Depois**

#### **ANTES (Manual)**
```r
# Usuário precisa rodar sequencialmente:
source("R/pipeline/pipeline2023.R")              # 1. Atualiza dados
source("R/_draft/statusinvest_indicators.R")     # 2. Busca indicadores
tb <- get_fii_cards("https://...")               # 3. Manualmente
print(tb)                                         # 4. Interpreta manualmente
```

#### **DEPOIS (Com Skills)**
```bash
# Usuário digita no Claude Code:
"analisar FII HGLG11"

# Skill orquestra tudo automaticamente:
# 1. Verifica se dados estão atualizados (pipeline2023.R)
# 2. Busca indicadores (statusinvest_indicators.R)
# 3. Busca proventos (statusinvest_proventos.R)
# 4. Busca dados CVM (novo)
# 5. Calcula score (novo)
# 6. Gera relatório interpretado
```

---

### **Exemplo Real: Skill `/fii-analysis` Completo**

```yaml
name: fii-analysis
triggers: ["analisar FII {ticker}"]

workflow:
  step1_check_cache:
    description: "Verifica se dados estão atualizados"
    r_function: "R/pipeline/update_data.R::update_all_data"
    args:
      force: false

  step2_load_base:
    description: "Carrega dados locais"
    r_code: |
      portfolio <- readRDS("data/portfolio.rds")
      income <- readRDS("data/income.rds")
      quotations <- readRDS("data/quotations.rds")
      fiis <- readRDS("data/fiis.rds")

  step3_get_indicators:
    description: "Busca indicadores do Status Invest"
    r_function: "R/_draft/statusinvest_indicators.R::get_fii_cards"
    args:
      url: "https://statusinvest.com.br/fundos-imobiliarios/{ticker}"

  step4_get_proventos:
    description: "Busca proventos do Status Invest"
    r_function: "R/_draft/statusinvest_proventos.R::get_fii_earnings"
    args:
      filter: "{ticker}"
      start: "2023-01-01"
      end: "{today}"

  step5_calculate_score:
    description: "Calcula score multifatorial"
    r_function: "R/analysis/fii_score.R::calculate_full_score"
    args:
      ticker: "{ticker}"
      indicators: "{step3_output}"
      proventos: "{step4_output}"
      portfolio: "{step2_output.portfolio}"
      quotations: "{step2_output.quotations}"

  step6_generate_report:
    prompt: |
      Gere relatório de análise de {ticker} com:

      ## Score Final: {step5_output.total}/100

      ### Breakdown por Bloco:
      - Qualidade: {step5_output.quality}/100
      - Renda: {step5_output.income}/100
      - Valuation: {step5_output.valuation}/100
      - Risco: {step5_output.risk}/100

      ### Recomendação:
      {step5_output.recommendation}

      ### Justificativa:
      Baseado em:
      - Indicadores: consulte memory/fii-indicators.md
      - Thresholds: consulte docs/knowledge_base_refs.md

      Compare com mediana do segmento e explique os principais drivers.
```

---

### **Resumo da Integração**

| Componente Existente | Como os Skills Usam | Novo Componente Necessário |
|---------------------|---------------------|---------------------------|
| `data/*.rds` | Leitura direta | Scripts de atualização inteligente |
| `pipeline2023.R` | Chamada via `source()` ou funções | Wrapper `update_all_data()` |
| `statusinvest_indicators.R` | Chamada via funções | Consolidação em `fii_score.R` |
| `statusinvest_proventos.R` | Chamada via funções | Validação cruzada em `fii_data_quality.R` |
| — | — | Importador CVM (`fii_cvm_data.R`) |
| — | — | Funções de análise (`fii_score.R`, etc.) |
| — | — | Memória Claude (`fii-indicators.md`, etc.) |

**Princípio:** Skills **orquestram** código existente + novos módulos. Nada precisa ser reescrito, apenas **organizado e conectado**.

---

## Resumo Executivo

**4 skills principais** + memória estruturada + código R modular + docs = arquitetura escalável.

**Prioridade 1:** Fase 1 (fundação) - organizar conhecimento antes de criar skills
**Prioridade 2:** Skill `/fii-score` - componente atômico reutilizável
**Prioridade 3:** Skill `/fii-analysis` - workflow completo mais usado
**Prioridade 4:** Skills `/fii-data-quality` e `/fii-portfolio-rebalance` conforme necessidade

**Princípio orientador:** Skills orquestram, memória informa, código calcula, docs explicam.

**Integração com código existente:** A arquitetura aproveita 100% do código atual (`pipeline2023.R`, `statusinvest_*.R`) como building blocks, adicionando apenas camadas de orquestração (skills) e análise (novos scripts em `R/analysis/`).
