# Relatório Visual: Seu Portfolio vs Empiricus

**Data:** 2026-03-21
**Total de Visualizações:** 10 gráficos

---

## 📊 Visualizações Geradas

### 1. Número de Ativos por Carteira
**Arquivo:** `plots/01_numero_ativos.png`

Compara o número de ativos em cada carteira. Seu portfolio tem **61 ativos**, 6x mais que a média da Empiricus (5-10 ativos).

**Insight Principal:** Você tem diversificação numérica excelente, mas pode ser demais para gerenciar.

---

### 2. Concentração nos Top 3 Ativos
**Arquivo:** `plots/02_concentracao_top3.png`

Mostra quanto % os top 3 ativos representam. Ideal é < 35%.

**Seu Portfolio:** 20.2% ✅ (EXCELENTE)
**Empiricus RENDA:** 44.5% ⚡
**Empiricus TÁTICA:** 45.0% ⚡
**Empiricus FOF:** 60.0% ⚠️

**Insight Principal:** Você tem metade da concentração de risco das carteiras Empiricus!

---

### 3. Índice Herfindahl-Hirschman (HHI)
**Arquivo:** `plots/03_indice_hhi.png`

Mede diversificação (menor = melhor). Abaixo de 0.10 = diversificado.

**Seu Portfolio:** 0.031 ✅ (3-6x mais diversificado que Empiricus)

**Insight Principal:** Seu portfolio é o mais diversificado de todos pela métrica HHI.

---

### 4. Comparação de Yields
**Arquivo:** `plots/04_yields.png`

**RENDA:** 9.92%
**TÁTICA:** 10.91%

**Paradoxo:** A carteira TÁTICA (foco em ganho de capital) rende MAIS que RENDA (foco em dividendos)!

**Insight Principal:** Estratégia de ganho de capital pode ser mais eficiente.

---

### 5. Concentração Multi-nível (Top 3, 5, 10)
**Arquivo:** `plots/05_concentracao_multinivel.png`

Compara concentração em múltiplos níveis.

**Seu Top 10:** 42.6% do portfolio
**Empiricus:** 100% (têm < 10 ativos)

**Insight Principal:** Você tem muito mais "cauda longa" de ativos menores.

---

### 6. Suas Top 10 Posições
**Arquivo:** `plots/06_top10_posicoes.png`

**Destaque:**
1. **PATL11** - 10.3% (seu maior holding)
2. **MGFF11** - 5.1%
3. **MXRF11** - 4.8%

**Total Top 10:** 42.6% do portfolio

**Insight Principal:** PATL11 domina (10%), considere realizar lucro parcial.

---

### 7. Performance das Top 10 Posições
**Arquivo:** `plots/07_performance_top10.png`

Mostra ganho/perda de cada ativo desde a compra.

**Destaque Positivo:** PATL11 com +266% 🚀
**Desafio:** Maioria dos outros com perdas entre -6% a -16%

**Insight Principal:** PATL11 salva o portfolio; outros precisam recuperar.

---

### 8. Distribuição de Pesos
**Arquivo:** `plots/08_distribuicao_pesos.png`

Histograma mostrando como os pesos estão distribuídos.

**Mediana:** ~1.6%
**Observação:** Muitos ativos com < 1% (posições muito pequenas)

**Insight Principal:** Consolidar posições < 1% melhoraria gestão sem perder diversificação.

---

### 9. Dashboard Comparativo
**Arquivo:** `plots/09_dashboard_comparativo.png`

Heatmap com todas as métricas lado a lado:
- N° Ativos
- Top 3 (%)
- HHI
- Score geral

**Insight Principal:** Visão consolidada de todas as métricas para comparação rápida.

---

### 10. Análise de Overlap
**Arquivo:** `plots/10_overlap_analysis.png`

Diagrama pizza mostrando sobreposição de ativos.

**Resultado Surpreendente:**
- **0 ativos em comum** entre você e Empiricus!
- 61 ativos exclusivamente seus
- 22 ativos exclusivamente Empiricus

**Insight Principal:** Estratégias completamente diferentes. Você pode estar descobrindo oportunidades que eles não veem, ou vice-versa.

---

## 🎯 Como Usar Estes Gráficos

### Para Apresentações
- Use gráficos 1, 2, 3 para mostrar diversificação
- Use gráfico 7 para discutir performance
- Use gráfico 10 para mostrar independência de estratégia

### Para Decisões de Investimento
- Gráfico 6: Identifica onde rebalancear
- Gráfico 7: Mostra quais ativos considerar vender
- Gráfico 8: Revela posições muito pequenas para consolidar

### Para Monitoramento
- Gráfico 2: Acompanhar se concentração aumenta
- Gráfico 3: Verificar se HHI se mantém baixo
- Gráfico 6: Ver se pesos mudam ao longo do tempo

---

## 📁 Localização dos Arquivos

Todos os gráficos estão em: `/Users/gsposito/Projects/fii_manager/plots/`

Formato: PNG de alta resolução (300 DPI)
Tamanho médio: 70-120 KB por gráfico

---

## 🔄 Regenerando os Gráficos

Para atualizar as visualizações após mudanças no portfolio:

```r
# 1. Atualizar dados
source("R/pipeline/main_portfolio.R")

# 2. Regenerar análises
source("R/analysis/analise_carteiras_externas.R")
source("R/analysis/comparacao_portfolio_vs_empiricus.R")

# 3. Regenerar visualizações
source("R/analysis/visualizacoes_comparacao.R")
```

---

## 💡 Próximos Passos

1. **Revisar visualmente** cada gráfico
2. **Identificar** padrões e outliers
3. **Decidir ações** baseado nos insights
4. **Monitorar** mudanças ao longo do tempo

---

*Gerado automaticamente pelo FII Manager Analysis System*
