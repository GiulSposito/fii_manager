#' Report Visualizations
#'
#' Generate all charts for portfolio analysis report
#'
#' @author Claude Code
#' @date 2026-03-21

library(tidyverse)
library(ggplot2)
library(plotly)
library(scales)
library(glue)

# Color palettes
COLOR_POSITIVE <- "#2ecc71"
COLOR_NEGATIVE <- "#e74c3c"
COLOR_NEUTRAL <- "#95a5a6"
COLOR_GRADIENT <- c("#e74c3c", "#f39c12", "#f1c40f", "#2ecc71")

#' Generate sector allocation pie chart
#'
#' @param sector_data Data from prepare_sector_allocation()
#' @return plotly object
#' @export
generate_sector_pie_chart <- function(sector_data) {

  # Limit to top 10 sectors, group rest as "Outros"
  top_sectors <- sector_data %>%
    arrange(desc(total_value)) %>%
    mutate(
      rank = row_number(),
      segment_display = if_else(rank <= 10, segment_label, "Outros")
    ) %>%
    group_by(segment_display) %>%
    summarise(
      total_value = sum(total_value),
      pct_portfolio = sum(pct_portfolio),
      .groups = "drop"
    )

  p <- plot_ly(
    data = top_sectors,
    labels = ~segment_display,
    values = ~total_value,
    type = "pie",
    textposition = "inside",
    textinfo = "label+percent",
    hovertemplate = paste0(
      "<b>%{label}</b><br>",
      "Valor: R$ %{value:,.0f}<br>",
      "Percentual: %{percent}<br>",
      "<extra></extra>"
    ),
    marker = list(
      line = list(color = "#ffffff", width = 2)
    )
  ) %>%
    layout(
      title = list(
        text = "Alocação por Setor",
        font = list(size = 16, family = "Arial")
      ),
      showlegend = TRUE,
      legend = list(
        orientation = "v",
        x = 1.1,
        y = 0.5
      )
    )

  return(p)
}

#' Generate top performers bar chart
#'
#' @param top_data Data from prepare_top_performers()
#' @return plotly object
#' @export
generate_top_performers_bar <- function(top_data) {

  p <- ggplot(top_data, aes(x = reorder(ticker, return_pct), y = return_pct)) +
    geom_col(aes(fill = return_pct), show.legend = FALSE) +
    geom_text(aes(label = sprintf("%.1f%%", return_pct)),
              hjust = -0.2, size = 3) +
    scale_fill_gradient2(
      low = "#f39c12",
      mid = "#2ecc71",
      high = "#27ae60",
      midpoint = 50
    ) +
    coord_flip() +
    labs(
      title = "Top 10 Melhores Posições",
      subtitle = "Retorno Total (Capital + Dividendos)",
      x = NULL,
      y = "Retorno (%)"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 11),
      axis.text = element_text(size = 10)
    )

  ggplotly(p, tooltip = c("x", "y")) %>%
    layout(
      hoverlabel = list(bgcolor = "white", font = list(size = 12))
    )
}

#' Generate bottom performers bar chart
#'
#' @param bottom_data Data from prepare_bottom_performers()
#' @return plotly object
#' @export
generate_bottom_performers_bar <- function(bottom_data) {

  p <- ggplot(bottom_data, aes(x = reorder(ticker, -return_pct), y = return_pct)) +
    geom_col(aes(fill = return_pct), show.legend = FALSE) +
    geom_text(aes(label = sprintf("%.1f%%", return_pct)),
              hjust = 1.2, size = 3, color = "white") +
    scale_fill_gradient2(
      low = "#c0392b",
      mid = "#e74c3c",
      high = "#f39c12",
      midpoint = -50
    ) +
    coord_flip() +
    labs(
      title = "Top 10 Piores Posições",
      subtitle = "Retorno Total (Capital + Dividendos)",
      x = NULL,
      y = "Retorno (%)"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 11),
      axis.text = element_text(size = 10)
    )

  ggplotly(p, tooltip = c("x", "y")) %>%
    layout(
      hoverlabel = list(bgcolor = "white", font = list(size = 12))
    )
}

#' Generate score histogram
#'
#' @param score_data Data from prepare_score_distribution()
#' @return plotly object
#' @export
generate_score_histogram <- function(score_data) {

  p <- ggplot(score_data, aes(x = total_score)) +
    geom_histogram(
      aes(fill = after_stat(x)),
      bins = 20,
      color = "white",
      linewidth = 0.5
    ) +
    geom_vline(
      aes(xintercept = mean(total_score, na.rm = TRUE)),
      linetype = "dashed",
      color = "#e74c3c",
      linewidth = 1
    ) +
    scale_fill_gradient2(
      low = "#e74c3c",
      mid = "#f1c40f",
      high = "#2ecc71",
      midpoint = 35,
      guide = "none"
    ) +
    labs(
      title = "Distribuição de Scores no Portfólio",
      subtitle = glue("Média: {round(mean(score_data$total_score, na.rm = TRUE), 1)} | Mediana: {round(median(score_data$total_score, na.rm = TRUE), 1)}"),
      x = "Score Total",
      y = "Número de FIIs"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 11)
    )

  ggplotly(p) %>%
    layout(
      hoverlabel = list(bgcolor = "white", font = list(size = 12))
    )
}

#' Generate dividend dual bar chart (invested vs dividends received)
#'
#' @param portfolio_csv Portfolio data
#' @param top_n Number of FIIs to show
#' @return plotly object
#' @export
generate_dividend_dual_bar <- function(portfolio_csv, top_n = 15) {

  top_div_data <- portfolio_csv %>%
    filter(!is.na(total_dividends), total_dividends > 0) %>%
    arrange(desc(total_dividends)) %>%
    head(top_n) %>%
    select(ticker, invested, total_dividends) %>%
    pivot_longer(
      cols = c(invested, total_dividends),
      names_to = "metric",
      values_to = "value"
    ) %>%
    mutate(
      metric = case_when(
        metric == "invested" ~ "Investido",
        metric == "total_dividends" ~ "Dividendos Recebidos"
      )
    )

  p <- ggplot(top_div_data, aes(x = reorder(ticker, -value), y = value, fill = metric)) +
    geom_col(position = "dodge", width = 0.7) +
    scale_fill_manual(
      values = c("Investido" = "#3498db", "Dividendos Recebidos" = "#2ecc71")
    ) +
    scale_y_continuous(labels = label_number(prefix = "R$ ", big.mark = ".")) +
    labs(
      title = glue("Top {top_n} FIIs por Dividendos Recebidos"),
      subtitle = "Comparação: Investido vs Dividendos",
      x = NULL,
      y = "Valor (R$)",
      fill = NULL
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 11),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "top"
    )

  ggplotly(p) %>%
    layout(
      legend = list(orientation = "h", x = 0.5, xanchor = "center", y = 1.1),
      hoverlabel = list(bgcolor = "white", font = list(size = 12))
    )
}

#' Generate dividend timeline chart
#'
#' @param timeline_data Data from prepare_dividend_timeline()
#' @return plotly object
#' @export
generate_dividend_timeline <- function(timeline_data) {

  # Filter last 36 months
  recent_data <- timeline_data %>%
    arrange(desc(year_month)) %>%
    head(36) %>%
    arrange(year_month)

  p <- plot_ly(data = recent_data) %>%
    add_bars(
      x = ~year_month,
      y = ~total_dividends,
      name = "Dividendos Mensais",
      marker = list(color = "#3498db"),
      hovertemplate = paste0(
        "<b>%{x|%b/%Y}</b><br>",
        "Dividendos: R$ %{y:,.2f}<br>",
        "<extra></extra>"
      )
    ) %>%
    add_lines(
      x = ~year_month,
      y = ~rolling_avg_6m,
      name = "Média Móvel 6M",
      line = list(color = "#e74c3c", width = 2),
      hovertemplate = paste0(
        "<b>%{x|%b/%Y}</b><br>",
        "Média 6M: R$ %{y:,.2f}<br>",
        "<extra></extra>"
      )
    ) %>%
    layout(
      title = list(
        text = "Evolução de Dividendos Recebidos (Últimos 36 Meses)",
        font = list(size = 16, family = "Arial")
      ),
      xaxis = list(
        title = "Mês",
        type = "date"
      ),
      yaxis = list(
        title = "Dividendos (R$)",
        tickformat = ",.0f"
      ),
      legend = list(
        orientation = "h",
        x = 0.5,
        xanchor = "center",
        y = 1.1
      ),
      hovermode = "x unified"
    )

  return(p)
}

#' Generate concentration treemap
#'
#' @param portfolio_csv Portfolio data
#' @return plotly object
#' @export
generate_concentration_treemap <- function(portfolio_csv) {

  treemap_data <- portfolio_csv %>%
    filter(!is.na(current_value), current_value > 0) %>%
    arrange(desc(current_value)) %>%
    mutate(
      pct_portfolio = current_value / sum(current_value) * 100,
      label = glue("{ticker}<br>{sprintf('%.1f%%', pct_portfolio)}"),
      color_value = return_with_div * 100
    )

  p <- plot_ly(
    data = treemap_data,
    type = "treemap",
    labels = ~ticker,
    parents = "",
    values = ~current_value,
    text = ~glue("R$ {formatC(round(current_value), format='f', big.mark='.', decimal.mark=',', digits=0)}<br>Retorno: {sprintf('%.1f%%', color_value)}"),
    marker = list(
      colorscale = list(
        c(0, "#e74c3c"),
        c(0.5, "#f1c40f"),
        c(1, "#2ecc71")
      ),
      colors = ~color_value,
      line = list(color = "white", width = 2)
    ),
    textposition = "middle center",
    hovertemplate = paste0(
      "<b>%{label}</b><br>",
      "%{text}<br>",
      "<extra></extra>"
    )
  ) %>%
    layout(
      title = list(
        text = "Concentração do Portfólio",
        font = list(size = 16, family = "Arial")
      )
    )

  return(p)
}

#' Generate return vs DY scatter plot
#'
#' @param portfolio_csv Portfolio data
#' @return plotly object
#' @export
generate_return_scatter <- function(portfolio_csv) {

  scatter_data <- portfolio_csv %>%
    filter(
      !is.na(return_with_div),
      !is.na(div_yield_on_cost),
      current_value > 0
    ) %>%
    mutate(
      return_pct = return_with_div * 100,
      dy_pct = div_yield_on_cost * 100,
      quadrant = case_when(
        return_pct > 0 & dy_pct > 8 ~ "Alto Retorno + Alto DY",
        return_pct > 0 & dy_pct <= 8 ~ "Alto Retorno + Baixo DY",
        return_pct <= 0 & dy_pct > 8 ~ "Baixo Retorno + Alto DY",
        TRUE ~ "Baixo Retorno + Baixo DY"
      )
    )

  p <- plot_ly(
    data = scatter_data,
    x = ~dy_pct,
    y = ~return_pct,
    type = "scatter",
    mode = "markers+text",
    text = ~ticker,
    textposition = "top center",
    marker = list(
      size = ~sqrt(current_value) / 10,
      color = ~return_pct,
      colorscale = list(
        c(0, "#e74c3c"),
        c(0.5, "#f1c40f"),
        c(1, "#2ecc71")
      ),
      showscale = TRUE,
      colorbar = list(title = "Retorno (%)")
    ),
    hovertemplate = paste0(
      "<b>%{text}</b><br>",
      "DY on Cost: %{x:.1f}%<br>",
      "Retorno Total: %{y:.1f}%<br>",
      "<extra></extra>"
    )
  ) %>%
    layout(
      title = list(
        text = "Retorno Total vs Dividend Yield on Cost",
        font = list(size = 16, family = "Arial")
      ),
      xaxis = list(
        title = "Dividend Yield on Cost (%)",
        zeroline = TRUE,
        zerolinecolor = "#95a5a6"
      ),
      yaxis = list(
        title = "Retorno Total (%)",
        zeroline = TRUE,
        zerolinecolor = "#95a5a6"
      ),
      shapes = list(
        # Vertical line at DY = 8%
        list(
          type = "line",
          x0 = 8, x1 = 8,
          y0 = min(scatter_data$return_pct), y1 = max(scatter_data$return_pct),
          line = list(color = "#95a5a6", dash = "dash")
        ),
        # Horizontal line at return = 0%
        list(
          type = "line",
          x0 = 0, x1 = max(scatter_data$dy_pct),
          y0 = 0, y1 = 0,
          line = list(color = "#95a5a6", dash = "dash")
        )
      )
    )

  return(p)
}

#' Generate Empiricus comparison bar chart
#'
#' @param comparison_data Data from prepare_empiricus_comparison()
#' @return plotly object
#' @export
generate_empiricus_comparison <- function(comparison_data) {

  p <- ggplot(comparison_data, aes(x = portfolio, y = avg_dy, fill = portfolio)) +
    geom_col(width = 0.6, show.legend = FALSE) +
    geom_text(aes(label = sprintf("%.1f%%", avg_dy)),
              vjust = -0.5, size = 4, fontface = "bold") +
    scale_fill_manual(
      values = c(
        "Seu Portfolio" = "#3498db",
        "Empiricus Renda" = "#2ecc71",
        "Empiricus Tática" = "#f39c12"
      )
    ) +
    labs(
      title = "Comparação de Dividend Yield",
      subtitle = "Seu Portfólio vs Carteiras Empiricus",
      x = NULL,
      y = "Dividend Yield Médio (%)"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 11),
      axis.text.x = element_text(angle = 0, hjust = 0.5)
    )

  ggplotly(p) %>%
    layout(
      hoverlabel = list(bgcolor = "white", font = list(size = 12))
    )
}

#' Generate score components radar chart
#'
#' @param score_data Data from prepare_score_distribution()
#' @param ticker Optional ticker to highlight (default: portfolio average)
#' @return plotly object
#' @export
generate_score_radar <- function(score_data, ticker = NULL) {

  if (!is.null(ticker)) {
    # Single FII radar
    fii_scores <- score_data %>%
      filter(ticker == !!ticker) %>%
      select(quality, income, valuation, risk) %>%
      pivot_longer(everything(), names_to = "dimension", values_to = "score") %>%
      mutate(dimension = str_to_title(dimension))

    title_text <- glue("Score Components: {ticker}")

  } else {
    # Portfolio average radar
    fii_scores <- score_data %>%
      summarise(
        quality = mean(quality, na.rm = TRUE),
        income = mean(income, na.rm = TRUE),
        valuation = mean(valuation, na.rm = TRUE),
        risk = mean(risk, na.rm = TRUE)
      ) %>%
      pivot_longer(everything(), names_to = "dimension", values_to = "score") %>%
      mutate(dimension = str_to_title(dimension))

    title_text <- "Score Components: Portfolio Average"
  }

  p <- plot_ly(
    type = "scatterpolar",
    mode = "lines+markers",
    fill = "toself"
  ) %>%
    add_trace(
      r = fii_scores$score,
      theta = fii_scores$dimension,
      name = title_text,
      fillcolor = "rgba(52, 152, 219, 0.3)",
      line = list(color = "#3498db", width = 2),
      marker = list(color = "#3498db", size = 8)
    ) %>%
    layout(
      polar = list(
        radialaxis = list(
          visible = TRUE,
          range = c(0, 25)
        )
      ),
      title = list(
        text = title_text,
        font = list(size = 16, family = "Arial")
      )
    )

  return(p)
}
