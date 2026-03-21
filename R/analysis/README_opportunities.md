# FII Opportunities - Intelligent Opportunity Detection

Sistema inteligente de detecção de oportunidades de investimento em FIIs com análise multi-fatorial, detecção de padrões e recomendações contextuais.

## Visão Geral

O módulo `fii_opportunities.R` oferece:

1. **Screener Avançado**: Filtragem multi-critério com operadores AND/OR e ranking customizável
2. **Detecção de Padrões**: Mean reversion, breakouts, momentum positivo, value traps
3. **Alertas Automáticos**: Monitoramento de portfolio com alertas de deterioração
4. **Recomendações Contextuais**: Sugestões personalizadas baseadas em perfil do investidor
5. **Relatório Consolidado**: Análise completa de oportunidades em um único report

## Pré-requisitos

O sistema requer scores pré-calculados e enriquecidos com indicadores avançados:

```r
# 1. Gerar scores básicos
source("./R/transform/fii_score_pipeline.R")
basic_scores <- run_scoring_pipeline()

# 2. Enriquecer com indicadores profundos
source("./R/transform/fii_deep_indicators.R")
cache <- load_deep_indicators_cache()
scores_enriched <- enrich_scores_with_deep_indicators(basic_scores, cache)

# 3. Carregar módulo de oportunidades
source("./R/analysis/fii_opportunities.R")
```

## 1. Screener Avançado

### Uso Básico

```r
# Definir critérios de filtragem
criteria <- list(
  total_score = list(min = 70),           # Score mínimo de 70
  dy_12m = list(min = 0.08, max = 0.15),  # DY entre 8% e 15%
  pvp = list(max = 1.0),                  # P/VP até 1.0
  vacancia = list(max = 0.10),            # Vacância até 10%
  momentum_3m = list(min = 0)             # Momentum positivo
)

# Buscar oportunidades
opportunities <- find_opportunities_advanced(
  scores_enriched,
  criteria = criteria,
  operator = "AND",                       # Todas condições devem ser atendidas
  blacklist = c("XPML11", "HGLG11"),     # Tickers a excluir
  ranking_weights = c(                    # Pesos customizados para ranking
    quality = 0.25,
    income = 0.35,
    valuation = 0.25,
    risk = 0.15
  )
)
```

### Operadores

- **AND**: Todas as condições devem ser atendidas (mais restritivo)
- **OR**: Qualquer condição pode ser atendida (mais abrangente)

### Critérios Disponíveis

Qualquer coluna em `scores_enriched` pode ser usada como critério:

**Scores básicos:**
- `total_score`, `quality`, `income`, `valuation`, `risk`
- `dy_12m`, `pvp`, `vacancia`

**Indicadores avançados:**
- `alavancagem`, `concentracao_cotistas`, `estabilidade_patrimonio`
- `momentum_3m`, `momentum_6m`, `momentum_12m`
- `zscore_dy`, `zscore_pvp`, `percentile_dy`, `percentile_pvp`
- `relative_strength_12m`

### Ranking Customizado

Se `ranking_weights` for fornecido, um `custom_score` é calculado:

```r
custom_score = quality * 0.25 + income * 0.35 + valuation * 0.25 + risk * 0.15
```

Pesos devem somar 1.0 (normalização automática).

## 2. Detecção de Padrões

### Mean Reversion

Identifica FIIs negociando abaixo da média histórica de P/VP (desconto temporário):

```r
mean_rev <- detect_mean_reversion(
  scores_enriched,
  scores_history = NULL,      # Carrega automaticamente de data/fii_scores_history.rds
  window = 12,                # Janela de 12 meses
  min_discount_pct = 10       # Desconto mínimo de 10%
)

# Retorna: ticker, pvp_atual, pvp_medio, desconto_pct, dias_abaixo, z_score_pvp
```

**Interpretação:**
- Alto desconto + qualidade alta = oportunidade de compra
- Requer histórico de pelo menos 5 pontos de dados

### Breakouts

Detecta FIIs que quebraram resistência de P/VP:

```r
breakouts <- detect_breakouts(
  scores_enriched,
  scores_history = NULL,
  threshold = 0.85,           # Percentil 85 como resistência
  lookback_months = 12
)

# Retorna: ticker, pvp_anterior, pvp_atual, resistance_pvp, breakout_pct
```

**Interpretação:**
- Breakout + fundamentos sólidos = momentum de valorização
- Breakout sem fundamentos = possível correção à frente

### Momentum Positivo

Identifica FIIs com momentum positivo sustentado em múltiplos períodos:

```r
momentum <- detect_momentum_positivo(
  scores_enriched,
  windows = c(3, 6),          # Janelas de 3 e 6 meses
  min_momentum = 0            # Momentum mínimo (%)
)

# Retorna: ticker, momentum_3m, momentum_6m, aceleracao
```

**Interpretação:**
- Momentum positivo em todas janelas = tendência forte
- `aceleracao > 0` = momentum acelerando
- `aceleracao < 0` = momentum desacelerando (possível reversão)

### Value Traps

Detecta FIIs "baratos" mas com qualidade comprometida (armadilhas de valor):

```r
traps <- detect_value_traps(
  scores_enriched,
  pvp_threshold = 0.90,       # P/VP até 0.90
  quality_threshold = 50      # Qualidade até 50
)

# Retorna: ticker, pvp, score_qualidade, razao_evitar
```

**Interpretação:**
- P/VP baixo pode indicar problemas estruturais, não oportunidade
- Evitar FIIs nesta lista mesmo que pareçam "baratos"

## 3. Alertas Automáticos de Portfolio

Monitora holdings em portfolio e gera alertas de deterioração:

```r
portfolio_tickers <- c("HGLG11", "MXRF11", "XPML11")

alerts <- generate_alerts_portfolio(
  portfolio_tickers,
  scores_enriched,
  scores_history = NULL,
  thresholds = list(
    vacancia_max = 0.20,       # Vacância máxima 20%
    alavancagem_max = 0.50,    # Alavancagem máxima 50%
    score_drop = 10,           # Queda de score de 10 pontos
    dy_drop_pct = 20,          # Queda de DY de 20%
    pvp_spike_pct = 15         # Aumento de P/VP de 15%
  )
)

# Retorna: ticker, tipo_alerta, severidade, valor_atual, threshold, mensagem
```

### Tipos de Alerta

1. **VACANCIA_ALTA**: Vacância acima do limite
2. **ALAVANCAGEM_ALTA**: Endividamento elevado
3. **QUEDA_SCORE**: Score caiu significativamente (30 dias)
4. **QUEDA_DY**: DY caiu significativamente (30 dias)
5. **VALORIZACAO_PVP**: P/VP subiu muito (possível sobrevalorização)

### Severidade

- **CRITICO**: Requer ação imediata
- **ALTO**: Requer atenção
- **MEDIO**: Monitorar

## 4. Recomendações Contextuais

Gera recomendações personalizadas baseadas no perfil do investidor:

```r
# Definir perfil do investidor
user_profile <- list(
  perfil_risco = "moderado",  # "conservador" | "moderado" | "agressivo"
  objetivo = "renda",          # "renda" | "valorizacao" | "hibrido"
  horizonte_anos = 5
)

# Gerar recomendação para um FII
rec <- recommend_actions(
  "HGLG11",
  scores_enriched,
  user_profile,
  current_portfolio = NULL     # Opcional: posições atuais
)

print_recommendation(rec)
```

### Estrutura da Recomendação

```r
list(
  ticker = "HGLG11",
  acao = "COMPRAR",            # COMPRAR | AUMENTAR | MANTER | REDUZIR | VENDER
  confianca = 85,              # 0-100%
  justificativa = "DY atrativo de 9.2%; P/VP abaixo de 1.0 (0.95); Qualidade elevada",
  sizing_sugerido = 5.0,       # % do portfolio
  preco_alvo = 102.50,         # R$
  stop_loss = 87.12,           # R$
  fit_scores = list(
    risk_fit = 90,
    objective_fit = 85
  ),
  overall_fit = 87
)
```

### Perfis de Risco

**Conservador:**
- Risk score máximo: 40
- Quality score mínimo: 60
- Stop loss: 10% abaixo do preço atual

**Moderado:**
- Risk score máximo: 60
- Quality score mínimo: 50
- Stop loss: 15% abaixo do preço atual

**Agressivo:**
- Risk score máximo: 80
- Quality score mínimo: 40
- Stop loss: 20% abaixo do preço atual

### Objetivos

**Renda:**
- Peso maior em `income_score` (70%) vs `valuation_score` (30%)
- Prioriza DY alto e consistência de proventos
- Target P/VP: 1.0

**Valorização:**
- Peso maior em `valuation_score` (70%) vs `income_score` (30%)
- Prioriza P/VP baixo e potencial de upside
- Target P/VP: 1.1

**Híbrido:**
- Peso igual entre `income_score` e `valuation_score` (50/50)
- Balanceamento entre renda e valorização

## 5. Relatório Consolidado

Gera análise completa consolidando todas as funcionalidades:

```r
report <- generate_opportunities_report(
  scores_enriched,
  portfolio_tickers = c("HGLG11", "MXRF11"),  # Opcional
  user_profile = list(...),                    # Opcional
  top_n = 10
)

print_opportunities_report(report)

# Salvar para análise posterior
saveRDS(report, glue("data/opportunities_{Sys.Date()}.rds"))
```

### Estrutura do Relatório

```r
list(
  oportunidades_compra = tibble(...),        # Top N oportunidades ranqueadas
  padroes_detectados = list(
    mean_reversion = tibble(...),
    breakouts = tibble(...),
    momentum_positivo = tibble(...),
    value_traps = tibble(...)
  ),
  alertas_portfolio = tibble(...),           # Se portfolio fornecido
  recomendacoes = list(...),                 # Se user_profile fornecido
  summary = list(
    total_oportunidades = 10,
    distribuicao_segmentos = tibble(...),
    range_scores = list(min, max, mean),
    data_analise = "2026-03-21 10:30:00"
  )
)
```

## Exemplos Completos

### Exemplo 1: Screening de Fundos de Papel

```r
# Buscar fundos de papel com DY alto e baixa vacância
criteria <- list(
  tipo_fii = list(equals = "Papel"),  # Se suportado
  dy_12m = list(min = 0.10),
  vacancia = list(max = 0.05),
  quality = list(min = 70)
)

paper_opps <- find_opportunities_advanced(
  scores_enriched %>% filter(str_detect(tipo_fii, "Papel")),
  criteria = criteria,
  operator = "AND"
)
```

### Exemplo 2: Monitoramento Completo de Portfolio

```r
# Carregar portfolio
portfolio <- readRDS("data/portfolio.rds")
tickers <- unique(portfolio$ticker)

# Gerar alertas
alerts <- generate_alerts_portfolio(tickers, scores_enriched)

# Gerar recomendações para cada posição
recommendations <- map(tickers, ~recommend_actions(
  .x, scores_enriched, user_profile
))

# Identificar posições problemáticas
problematic <- alerts %>%
  filter(severidade %in% c("CRITICO", "ALTO"))

# Identificar posições com recomendação VENDER/REDUZIR
to_reduce <- recommendations %>%
  keep(~.x$acao %in% c("VENDER", "REDUZIR")) %>%
  map_chr(~.x$ticker)
```

### Exemplo 3: Busca de Oportunidades Contra-Cíclicas

```r
# FIIs com desconto temporário mas fundamentos sólidos
mean_rev <- detect_mean_reversion(
  scores_enriched,
  window = 12,
  min_discount_pct = 15
)

# Filtrar por qualidade alta
quality_discounts <- mean_rev %>%
  filter(total_score >= 70, desconto_pct >= 20) %>%
  arrange(desc(desconto_pct))
```

## Integração com Pipeline

```r
# 1. Atualizar dados e scores
source("./R/pipeline/main_portfolio.R")  # Atualiza dados brutos

source("./R/transform/fii_score_pipeline.R")
scores <- run_scoring_pipeline(force = TRUE)

# 2. Enriquecer com indicadores profundos
source("./R/transform/fii_deep_indicators.R")
cache <- load_deep_indicators_cache()
scores_enriched <- enrich_scores_with_deep_indicators(scores, cache)

# 3. Gerar relatório de oportunidades
source("./R/analysis/fii_opportunities.R")
report <- generate_opportunities_report(
  scores_enriched,
  portfolio_tickers = unique(readRDS("data/portfolio.rds")$ticker),
  user_profile = list(perfil_risco = "moderado", objetivo = "renda", horizonte_anos = 5),
  top_n = 15
)

print_opportunities_report(report)
```

## Troubleshooting

### Erro: "Missing momentum indicators"

**Causa**: Scores não foram enriquecidos com deep indicators

**Solução**:
```r
cache <- load_deep_indicators_cache()
scores_enriched <- enrich_scores_with_deep_indicators(scores, cache)
```

### Erro: "No scores history available"

**Causa**: Arquivo `data/fii_scores_history.rds` não existe ou está vazio

**Solução**: Execute o pipeline ao menos 2 vezes com intervalo de dias para gerar histórico:
```r
run_scoring_pipeline(force = TRUE)
# Aguardar alguns dias...
run_scoring_pipeline(force = TRUE)
```

### Nenhuma oportunidade encontrada

**Causa**: Critérios muito restritivos

**Solução**: Relaxe os critérios ou use operador "OR":
```r
opportunities <- find_opportunities_advanced(
  scores_enriched,
  criteria = criteria,
  operator = "OR"  # Qualquer critério satisfeito
)
```

## Boas Práticas

1. **Atualizar dados regularmente**: Execute pipeline semanal para manter scores frescos
2. **Revisar alertas diariamente**: Monitore portfolio para detectar deterioração precoce
3. **Combinar análises**: Use múltiplos métodos (screener + padrões + recomendações)
4. **Validar manualmente**: Sistema é auxiliar, não substitui due diligence
5. **Ajustar perfil**: Revise user_profile periodicamente conforme objetivos mudam
6. **Documentar decisões**: Salve relatórios para auditoria de decisões

## Métricas de Qualidade

O sistema considera scores de:
- **Quality** (0-100): Gestão, eficiência, concentração
- **Income** (0-100): DY, consistência de proventos
- **Valuation** (0-100): P/VP, liquidez, momentum
- **Risk** (0-100): Vacância, alavancagem, volatilidade

Score total é média ponderada dos 4 blocos.

## Limitações

1. **Dados históricos**: Padrões temporais requerem pelo menos 5-6 pontos históricos
2. **Qualidade dos dados**: Resultados dependem de dados precisos do CVM/APIs
3. **Market timing**: Sistema não prevê movimentos de curto prazo do mercado
4. **Contexto macro**: Não considera fatores macroeconômicos (SELIC, inflação, etc.)
5. **Subjetividade**: Thresholds e pesos são heurísticas, não verdades absolutas

## Referências

- **fii_analysis.R**: Funções básicas de análise
- **fii_deep_indicators.R**: Indicadores avançados (momentum, z-scores, etc.)
- **fii_comparison.R**: Comparação com peers e mercado
- **fii_score_pipeline.R**: Pipeline de cálculo de scores

## Suporte

Para dúvidas ou problemas:
1. Verifique logs do console para erros específicos
2. Valide que todos pré-requisitos foram executados
3. Revise a documentação inline (roxygen2) nas funções
4. Teste com script `R/_draft/test_opportunities.R`
