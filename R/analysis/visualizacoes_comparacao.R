# Visualizações da Comparação: Portfolio vs Empiricus
# Gráficos para análise comparativa

library(tidyverse)
library(ggplot2)
library(patchwork)  # Para combinar gráficos
library(scales)

# Load utility functions
source("R/utils/ticker_utils.R")

# Load comparison data
comp_data <- readRDS("data/comparacao_portfolio_empiricus.rds")
analise_empiricus <- readRDS("data/analise_carteiras_externas.rds")
carteiras_empiricus <- readRDS("data/carteiras_externas.rds")

# Create plots directory
dir.create("plots", showWarnings = FALSE)

# Theme for all plots
theme_fii <- function() {
  theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 11, color = "gray40"),
      axis.title = element_text(face = "bold", size = 10),
      legend.position = "bottom",
      panel.grid.minor = element_blank()
    )
}

# ===============================================================================
# 1. COMPARAÇÃO DE NÚMERO DE ATIVOS
# ===============================================================================

cat("📊 Gerando gráfico 1: Número de Ativos...\n")

df_ativos <- tibble(
  Carteira = factor(c("SEU\nPORTFOLIO", "RENDA", "TÁTICA", "FOF"),
                    levels = c("SEU\nPORTFOLIO", "RENDA", "TÁTICA", "FOF")),
  N_Ativos = c(
    comp_data$portfolio_metrics$n_assets,
    nrow(carteiras_empiricus$renda),
    nrow(carteiras_empiricus$tatica),
    nrow(carteiras_empiricus$fof)
  ),
  Tipo = c("Seu Portfolio", "Empiricus", "Empiricus", "Empiricus")
)

p1 <- ggplot(df_ativos, aes(x = Carteira, y = N_Ativos, fill = Tipo)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = N_Ativos), vjust = -0.5, fontface = "bold", size = 5) +
  scale_fill_manual(values = c("Seu Portfolio" = "#2E86AB", "Empiricus" = "#A23B72")) +
  labs(
    title = "Número de Ativos por Carteira",
    subtitle = "Seu portfolio tem 6x mais ativos que a média da Empiricus",
    x = NULL,
    y = "Número de Ativos",
    fill = NULL
  ) +
  theme_fii() +
  ylim(0, max(df_ativos$N_Ativos) * 1.15)

ggsave("plots/01_numero_ativos.png", p1, width = 10, height = 6, dpi = 300)

# ===============================================================================
# 2. COMPARAÇÃO DE CONCENTRAÇÃO (TOP 3)
# ===============================================================================

cat("📊 Gerando gráfico 2: Concentração Top 3...\n")

df_concentracao <- tibble(
  Carteira = factor(c("SEU\nPORTFOLIO", "RENDA", "TÁTICA", "FOF"),
                    levels = c("SEU\nPORTFOLIO", "RENDA", "TÁTICA", "FOF")),
  Top3_Pct = c(
    comp_data$concentration$top3_concentration * 100,
    analise_empiricus$renda$concentration$top3_concentration * 100,
    analise_empiricus$tatica$concentration$top3_concentration * 100,
    analise_empiricus$fof$concentration$top3_concentration * 100
  ),
  Tipo = c("Seu Portfolio", "Empiricus", "Empiricus", "Empiricus"),
  Avaliacao = case_when(
    Top3_Pct <= 35 ~ "Excelente",
    Top3_Pct <= 50 ~ "Moderado",
    TRUE ~ "Alto"
  )
)

p2 <- ggplot(df_concentracao, aes(x = Carteira, y = Top3_Pct, fill = Avaliacao)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 35, linetype = "dashed", color = "darkgreen", size = 1) +
  geom_hline(yintercept = 50, linetype = "dashed", color = "orange", size = 1) +
  geom_text(aes(label = sprintf("%.1f%%", Top3_Pct)), vjust = -0.5, fontface = "bold", size = 5) +
  scale_fill_manual(values = c("Excelente" = "#06A77D", "Moderado" = "#F77F00", "Alto" = "#D62828")) +
  annotate("text", x = 0.5, y = 35, label = "Ideal < 35%", hjust = 0, color = "darkgreen", size = 3) +
  annotate("text", x = 0.5, y = 50, label = "Limite 50%", hjust = 0, color = "orange", size = 3) +
  labs(
    title = "Concentração nos Top 3 Ativos",
    subtitle = "Menor é melhor - Seu portfolio tem metade da concentração da Empiricus",
    x = NULL,
    y = "% dos Top 3 Ativos",
    fill = "Avaliação"
  ) +
  theme_fii() +
  ylim(0, max(df_concentracao$Top3_Pct) * 1.15)

ggsave("plots/02_concentracao_top3.png", p2, width = 10, height = 6, dpi = 300)

# ===============================================================================
# 3. ÍNDICE HERFINDAHL (HHI)
# ===============================================================================

cat("📊 Gerando gráfico 3: Índice Herfindahl...\n")

df_hhi <- tibble(
  Carteira = factor(c("SEU\nPORTFOLIO", "RENDA", "TÁTICA", "FOF"),
                    levels = c("SEU\nPORTFOLIO", "RENDA", "TÁTICA", "FOF")),
  HHI = c(
    comp_data$concentration$herfindahl,
    analise_empiricus$renda$concentration$herfindahl,
    analise_empiricus$tatica$concentration$herfindahl,
    analise_empiricus$fof$concentration$herfindahl
  ),
  Tipo = c("Seu Portfolio", "Empiricus", "Empiricus", "Empiricus"),
  Avaliacao = case_when(
    HHI < 0.10 ~ "Diversificado",
    HHI < 0.15 ~ "Moderado",
    TRUE ~ "Concentrado"
  )
)

p3 <- ggplot(df_hhi, aes(x = Carteira, y = HHI, fill = Avaliacao)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 0.10, linetype = "dashed", color = "darkgreen", size = 1) +
  geom_hline(yintercept = 0.15, linetype = "dashed", color = "orange", size = 1) +
  geom_text(aes(label = sprintf("%.4f", HHI)), vjust = -0.5, fontface = "bold", size = 5) +
  scale_fill_manual(values = c("Diversificado" = "#06A77D", "Moderado" = "#F77F00", "Concentrado" = "#D62828")) +
  annotate("text", x = 0.5, y = 0.10, label = "< 0.10 = Diversificado", hjust = 0, color = "darkgreen", size = 3) +
  annotate("text", x = 0.5, y = 0.15, label = "< 0.15 = Moderado", hjust = 0, color = "orange", size = 3) +
  labs(
    title = "Índice Herfindahl-Hirschman (HHI)",
    subtitle = "Menor é melhor - Seu portfolio é 3-6x mais diversificado",
    x = NULL,
    y = "Índice HHI",
    fill = "Avaliação"
  ) +
  theme_fii() +
  ylim(0, max(df_hhi$HHI) * 1.15)

ggsave("plots/03_indice_hhi.png", p3, width = 10, height = 6, dpi = 300)

# ===============================================================================
# 4. COMPARAÇÃO DE YIELDS
# ===============================================================================

cat("📊 Gerando gráfico 4: Yields...\n")

df_yields <- tibble(
  Carteira = factor(c("RENDA", "TÁTICA"),
                    levels = c("RENDA", "TÁTICA")),
  Yield = c(
    analise_empiricus$renda$yields$mean_yield_anual,
    analise_empiricus$tatica$yields$mean_yield_anual
  )
)

p4 <- ggplot(df_yields, aes(x = Carteira, y = Yield, fill = Carteira)) +
  geom_col(width = 0.6) +
  geom_hline(yintercept = 10, linetype = "dashed", color = "gray50", size = 1) +
  geom_text(aes(label = sprintf("%.2f%%", Yield)), vjust = -0.5, fontface = "bold", size = 6) +
  scale_fill_manual(values = c("RENDA" = "#E63946", "TÁTICA" = "#06A77D")) +
  annotate("text", x = 0.5, y = 10, label = "Média Mercado ~10%", hjust = 0, color = "gray50", size = 3) +
  labs(
    title = "Yield Anualizado Médio",
    subtitle = "TÁTICA tem yield maior que RENDA (paradoxo!)",
    x = NULL,
    y = "Yield (%)",
    fill = NULL,
    caption = "Nota: Seu portfolio não tem dados de yield disponíveis"
  ) +
  theme_fii() +
  ylim(0, max(df_yields$Yield) * 1.15)

ggsave("plots/04_yields.png", p4, width = 10, height = 6, dpi = 300)

# ===============================================================================
# 5. CONCENTRAÇÃO MULTI-NÍVEL (Top 3, 5, 10)
# ===============================================================================

cat("📊 Gerando gráfico 5: Concentração Multi-nível...\n")

df_conc_multi <- tibble(
  Carteira = rep(c("SEU\nPORTFOLIO", "RENDA", "TÁTICA", "FOF"), each = 3),
  Nivel = rep(c("Top 3", "Top 5", "Top 10"), 4),
  Concentracao = c(
    # Seu portfolio
    comp_data$concentration$top3_concentration * 100,
    comp_data$concentration$top5_concentration * 100,
    comp_data$concentration$top10_concentration * 100,
    # RENDA
    analise_empiricus$renda$concentration$top3_concentration * 100,
    analise_empiricus$renda$concentration$top5_concentration * 100,
    100,  # Top 10 = 100% (só tem 10 ativos)
    # TÁTICA
    analise_empiricus$tatica$concentration$top3_concentration * 100,
    analise_empiricus$tatica$concentration$top5_concentration * 100,
    100,  # Top 10 = 100% (só tem 9 ativos)
    # FOF
    analise_empiricus$fof$concentration$top3_concentration * 100,
    100,  # Top 5 = 100% (só tem 5 ativos)
    100   # Top 10 = 100% (só tem 5 ativos)
  )
) %>%
  mutate(
    Nivel = factor(Nivel, levels = c("Top 3", "Top 5", "Top 10")),
    Carteira = factor(Carteira, levels = c("SEU\nPORTFOLIO", "RENDA", "TÁTICA", "FOF"))
  )

p5 <- ggplot(df_conc_multi, aes(x = Carteira, y = Concentracao, fill = Nivel)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Concentração Multi-nível",
    subtitle = "Comparação de concentração nos Top 3, 5 e 10 ativos",
    x = NULL,
    y = "% do Portfolio",
    fill = "Nível"
  ) +
  theme_fii() +
  ylim(0, 105)

ggsave("plots/05_concentracao_multinivel.png", p5, width = 12, height = 6, dpi = 300)

# ===============================================================================
# 6. TOP 10 POSIÇÕES DO SEU PORTFOLIO
# ===============================================================================

cat("📊 Gerando gráfico 6: Suas Top 10 Posições...\n")

top10_data <- comp_data$current_portfolio %>%
  arrange(desc(weight)) %>%
  head(10) %>%
  mutate(
    ticker = factor(ticker, levels = rev(ticker)),
    gain_color = ifelse(gain_loss_pct > 0, "Positivo", "Negativo")
  )

p6 <- ggplot(top10_data, aes(x = ticker, y = weight_pct, fill = gain_color)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", weight_pct)), hjust = -0.2, fontface = "bold", size = 4) +
  scale_fill_manual(values = c("Positivo" = "#06A77D", "Negativo" = "#D62828")) +
  coord_flip() +
  labs(
    title = "Suas Top 10 Posições",
    subtitle = sprintf("Total: %.1f%% do portfolio", sum(top10_data$weight_pct)),
    x = NULL,
    y = "% do Portfolio",
    fill = "Resultado"
  ) +
  theme_fii() +
  ylim(0, max(top10_data$weight_pct) * 1.15)

ggsave("plots/06_top10_posicoes.png", p6, width = 10, height = 8, dpi = 300)

# ===============================================================================
# 7. PERFORMANCE DO SEU PORTFOLIO (Top 10)
# ===============================================================================

cat("📊 Gerando gráfico 7: Performance Top 10...\n")

p7 <- ggplot(top10_data, aes(x = ticker, y = gain_loss_pct, fill = gain_color)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 0, linetype = "solid", color = "black", size = 0.5) +
  geom_text(aes(label = sprintf("%+.1f%%", gain_loss_pct)),
            hjust = ifelse(top10_data$gain_loss_pct > 0, -0.2, 1.2),
            fontface = "bold", size = 4) +
  scale_fill_manual(values = c("Positivo" = "#06A77D", "Negativo" = "#D62828")) +
  coord_flip() +
  labs(
    title = "Performance das Top 10 Posições",
    subtitle = "Ganho/Perda desde a compra",
    x = NULL,
    y = "Ganho/Perda (%)",
    fill = NULL
  ) +
  theme_fii()

ggsave("plots/07_performance_top10.png", p7, width = 10, height = 8, dpi = 300)

# ===============================================================================
# 8. DISTRIBUIÇÃO DE PESOS (HISTOGRAMA)
# ===============================================================================

cat("📊 Gerando gráfico 8: Distribuição de Pesos...\n")

p8 <- ggplot(comp_data$current_portfolio, aes(x = weight_pct)) +
  geom_histogram(bins = 30, fill = "#2E86AB", color = "white", alpha = 0.8) +
  geom_vline(xintercept = median(comp_data$current_portfolio$weight_pct),
             linetype = "dashed", color = "red", size = 1) +
  annotate("text",
           x = median(comp_data$current_portfolio$weight_pct) + 0.5,
           y = Inf,
           label = sprintf("Mediana: %.2f%%", median(comp_data$current_portfolio$weight_pct)),
           vjust = 2, color = "red", fontface = "bold") +
  labs(
    title = "Distribuição de Pesos no Seu Portfolio",
    subtitle = sprintf("%d ativos | Mediana: %.2f%% | Média: %.2f%%",
                      nrow(comp_data$current_portfolio),
                      median(comp_data$current_portfolio$weight_pct),
                      mean(comp_data$current_portfolio$weight_pct)),
    x = "% do Portfolio",
    y = "Número de Ativos"
  ) +
  theme_fii()

ggsave("plots/08_distribuicao_pesos.png", p8, width = 10, height = 6, dpi = 300)

# ===============================================================================
# 9. COMPARAÇÃO GERAL (DASHBOARD)
# ===============================================================================

cat("📊 Gerando gráfico 9: Dashboard Comparativo...\n")

# Create a simple comparison table visual
df_comparison <- tibble(
  Metrica = rep(c("N° Ativos", "Top 3 (%)", "HHI", "Score"), 4),
  Carteira = rep(c("SEU PORTFOLIO", "RENDA", "TÁTICA", "FOF"), each = 4),
  Valor = c(
    # Seu portfolio
    comp_data$portfolio_metrics$n_assets,
    comp_data$concentration$top3_concentration * 100,
    comp_data$concentration$herfindahl,
    comp_data$score,
    # RENDA
    nrow(carteiras_empiricus$renda),
    analise_empiricus$renda$concentration$top3_concentration * 100,
    analise_empiricus$renda$concentration$herfindahl,
    analise_empiricus$renda$score,
    # TÁTICA
    nrow(carteiras_empiricus$tatica),
    analise_empiricus$tatica$concentration$top3_concentration * 100,
    analise_empiricus$tatica$concentration$herfindahl,
    analise_empiricus$tatica$score,
    # FOF
    nrow(carteiras_empiricus$fof),
    analise_empiricus$fof$concentration$top3_concentration * 100,
    analise_empiricus$fof$concentration$herfindahl,
    analise_empiricus$fof$score
  ),
  Valor_Norm = c(
    # Normalizando para 0-100 (menor = melhor para concentração, maior = melhor para n_ativos e score)
    # Seu portfolio
    100, 100, 100, comp_data$score * 20,
    # RENDA
    16, 55, 28, analise_empiricus$renda$score * 20,
    # TÁTICA
    15, 54, 26, analise_empiricus$tatica$score * 20,
    # FOF
    8, 33, 16, analise_empiricus$fof$score * 20
  )
) %>%
  mutate(
    Carteira = factor(Carteira, levels = c("SEU PORTFOLIO", "RENDA", "TÁTICA", "FOF")),
    Metrica = factor(Metrica, levels = c("N° Ativos", "Top 3 (%)", "HHI", "Score"))
  )

p9 <- ggplot(df_comparison, aes(x = Metrica, y = Carteira, fill = Valor)) +
  geom_tile(color = "white", size = 1) +
  geom_text(aes(label = sprintf("%.2f", Valor)), fontface = "bold", size = 5) +
  scale_fill_gradient2(low = "#06A77D", mid = "#F77F00", high = "#D62828", midpoint = 50) +
  labs(
    title = "Dashboard Comparativo",
    subtitle = "Todas as métricas principais lado a lado",
    x = NULL,
    y = NULL,
    fill = "Valor"
  ) +
  theme_fii() +
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5),
    legend.position = "right"
  )

ggsave("plots/09_dashboard_comparativo.png", p9, width = 12, height = 6, dpi = 300)

# ===============================================================================
# 10. OVERLAP VISUALIZATION
# ===============================================================================

cat("📊 Gerando gráfico 10: Análise de Overlap...\n")

# Note: extractTicker() now sourced from R/utils/ticker_utils.R

empiricus_all <- unique(c(
  carteiras_empiricus$renda %>% mutate(ticker = extractTicker(Nome)) %>% pull(ticker),
  carteiras_empiricus$tatica %>% mutate(ticker = extractTicker(Nome)) %>% pull(ticker),
  carteiras_empiricus$fof %>% mutate(ticker = extractTicker(Nome)) %>% pull(ticker)
))

seu_portfolio <- comp_data$current_portfolio$ticker

overlap_data <- tibble(
  Categoria = c("Só Você", "Ambos", "Só Empiricus"),
  Quantidade = c(
    length(setdiff(seu_portfolio, empiricus_all)),
    length(intersect(seu_portfolio, empiricus_all)),
    length(setdiff(empiricus_all, seu_portfolio))
  )
) %>%
  mutate(
    Categoria = factor(Categoria, levels = c("Só Você", "Ambos", "Só Empiricus")),
    Pct = Quantidade / sum(Quantidade) * 100
  )

p10 <- ggplot(overlap_data, aes(x = "", y = Quantidade, fill = Categoria)) +
  geom_col(width = 1) +
  geom_text(aes(label = sprintf("%d\n(%.1f%%)", Quantidade, Pct)),
            position = position_stack(vjust = 0.5),
            fontface = "bold", size = 5, color = "white") +
  scale_fill_manual(values = c("Só Você" = "#2E86AB", "Ambos" = "#A23B72", "Só Empiricus" = "#F77F00")) +
  coord_polar(theta = "y") +
  labs(
    title = "Análise de Overlap: Você vs Empiricus",
    subtitle = sprintf("Total de %d ativos únicos", sum(overlap_data$Quantidade)),
    fill = NULL
  ) +
  theme_void() +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 11, color = "gray40", hjust = 0.5),
    legend.position = "bottom"
  )

ggsave("plots/10_overlap_analysis.png", p10, width = 8, height = 8, dpi = 300)

# ===============================================================================
# SUMMARY
# ===============================================================================

cat("\n")
cat(strrep("=", 80), "\n")
cat("✅ VISUALIZAÇÕES GERADAS COM SUCESSO!\n")
cat(strrep("=", 80), "\n\n")

cat("📁 Arquivos salvos em: plots/\n\n")

plots_list <- c(
  "01_numero_ativos.png         - Comparação de número de ativos",
  "02_concentracao_top3.png     - Concentração dos top 3 ativos",
  "03_indice_hhi.png            - Índice Herfindahl",
  "04_yields.png                - Comparação de yields",
  "05_concentracao_multinivel.png - Concentração multi-nível",
  "06_top10_posicoes.png        - Suas top 10 posições",
  "07_performance_top10.png     - Performance das top 10",
  "08_distribuicao_pesos.png    - Distribuição de pesos",
  "09_dashboard_comparativo.png - Dashboard completo",
  "10_overlap_analysis.png      - Análise de overlap"
)

for (plot in plots_list) {
  cat(sprintf("   ✓ %s\n", plot))
}

cat("\n")
cat("🎨 Todas as visualizações foram geradas!\n")
cat("   Abra os arquivos PNG para visualizar.\n\n")
