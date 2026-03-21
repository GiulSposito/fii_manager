#' FII Comparison - Peer Analysis
#'
#' Functions to compare FIIs using PRE-CALCULATED scores
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(lubridate)
library(glue)

if (file.exists("./R/analysis/fii_analysis.R")) {
  source("./R/analysis/fii_analysis.R", encoding = "UTF-8")
}

# ============================================================================
# PEER COMPARISON
# ============================================================================

#' Compare FII with peers
#'
#' @param ticker Target FII ticker
#' @param max_peers Number of peers (default: 5)
#' @return List with comparison data
#' @export
compare_with_peers <- function(ticker, max_peers = 5) {
  scores <- load_scores_for_analysis()
  cache <- readRDS("data/fiis.rds")

  # Get target info
  target_score <- scores %>% filter(ticker == !!ticker)

  if (nrow(target_score) == 0) {
    stop(glue("No score found for {ticker}"))
  }

  target_type <- target_score$tipo_fii

  # Get peer scores (same segment)
  peer_scores <- scores %>%
    filter(str_detect(tipo_fii, !!target_type),
           ticker != !!ticker) %>%
    arrange(desc(total_score)) %>%
    head(max_peers)

  # Calculate peer statistics
  peer_stats <- peer_scores %>%
    summarise(
      n_peers = n(),
      mean_total_score = mean(total_score, na.rm = TRUE),
      median_total_score = median(total_score, na.rm = TRUE),
      mean_quality = mean(quality, na.rm = TRUE),
      mean_income = mean(income, na.rm = TRUE),
      mean_valuation = mean(valuation, na.rm = TRUE),
      mean_risk = mean(risk, na.rm = TRUE),
      mean_dy = mean(dy_12m, na.rm = TRUE),
      mean_pvp = mean(pvp, na.rm = TRUE)
    )

  # Calculate relative performance
  relative_perf <- tibble(
    metric = c("Total Score", "Quality", "Income", "Valuation", "Risk", "DY 12M", "P/VP"),
    target = c(
      target_score$total_score,
      target_score$quality,
      target_score$income,
      target_score$valuation,
      target_score$risk,
      target_score$dy_12m,
      target_score$pvp
    ),
    peer_mean = c(
      peer_stats$mean_total_score,
      peer_stats$mean_quality,
      peer_stats$mean_income,
      peer_stats$mean_valuation,
      peer_stats$mean_risk,
      peer_stats$mean_dy,
      peer_stats$mean_pvp
    ),
    difference = target - peer_mean,
    better_than_peers = target > peer_mean
  )

  result <- list(
    ticker = ticker,
    target_score = target_score,
    peer_scores = peer_scores,
    peer_stats = peer_stats,
    relative_performance = relative_perf,
    comparison_date = Sys.time()
  )

  return(result)
}

#' Print peer comparison report
#'
#' @param comparison Result from compare_with_peers()
#' @export
print_comparison_report <- function(comparison) {
  target <- comparison$ticker
  target_score <- comparison$target_score$total_score
  peer_mean <- comparison$peer_stats$mean_total_score

  better_metrics <- comparison$relative_performance %>%
    filter(better_than_peers) %>%
    pull(metric)

  worse_metrics <- comparison$relative_performance %>%
    filter(!better_than_peers) %>%
    pull(metric)

  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat(glue("           COMPARATIVE ANALYSIS: {target}\n"))
  cat("═══════════════════════════════════════════════════════════════\n\n")

  cat("📊 Score Comparison:\n")
  cat(glue("  {target}: {round(target_score, 1)}/100\n"))
  cat(glue("  Peer Average: {round(peer_mean, 1)}/100\n"))
  cat(glue("  Difference: {round(target_score - peer_mean, 1)} points\n\n"))

  cat("✅ Better than peers in:\n")
  for (metric in better_metrics) {
    cat(glue("   • {metric}\n"))
  }

  cat("\n⚠️  Worse than peers in:\n")
  for (metric in worse_metrics) {
    cat(glue("   • {metric}\n"))
  }

  cat("\n📈 Detailed Comparison:\n\n")
  print(comparison$relative_performance)

  cat("\n🏆 Peer Ranking:\n\n")
  comparison$peer_scores %>%
    select(ticker, total_score, quality, income, valuation, risk,
           dy_12m, pvp, recommendation) %>%
    print()

  cat("\n")
}

# ============================================================================
# PORTFOLIO VS MARKET
# ============================================================================

#' Compare portfolio against market
#'
#' @export
portfolio_vs_market <- function() {
  scores <- load_scores_for_analysis()
  portfolio <- readRDS("data/portfolio.rds")

  # Portfolio scores
  portfolio_tickers <- unique(portfolio$ticker)
  portfolio_scores <- scores %>%
    filter(ticker %in% portfolio_tickers)

  # Market sample (top 100 by scores)
  market_scores <- scores %>%
    arrange(desc(total_score)) %>%
    head(100)

  # Statistics
  portfolio_stats <- portfolio_scores %>%
    summarise(
      n = n(),
      mean_score = mean(total_score, na.rm = TRUE),
      median_score = median(total_score, na.rm = TRUE),
      mean_dy = mean(dy_12m, na.rm = TRUE),
      mean_pvp = mean(pvp, na.rm = TRUE)
    )

  market_stats <- market_scores %>%
    summarise(
      n = n(),
      mean_score = mean(total_score, na.rm = TRUE),
      median_score = median(total_score, na.rm = TRUE),
      mean_dy = mean(dy_12m, na.rm = TRUE),
      mean_pvp = mean(pvp, na.rm = TRUE)
    )

  result <- list(
    portfolio = portfolio_scores,
    market = market_scores,
    portfolio_stats = portfolio_stats,
    market_stats = market_stats,
    comparison_date = Sys.time()
  )

  return(result)
}

#' Print portfolio vs market report
#'
#' @param comparison Result from portfolio_vs_market()
#' @export
print_portfolio_vs_market <- function(comparison) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("              PORTFOLIO VS MARKET COMPARISON\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  cat("📊 PORTFOLIO STATS:\n")
  print(comparison$portfolio_stats)

  cat("\n📊 MARKET STATS (Top 100):\n")
  print(comparison$market_stats)

  cat("\n\n💡 INSIGHTS:\n")

  diff_score <- comparison$portfolio_stats$mean_score -
                comparison$market_stats$mean_score

  if (diff_score > 0) {
    cat(glue("  ✅ Portfolio outperforming market by {round(diff_score, 1)} points\n"))
  } else {
    cat(glue("  ⚠️  Portfolio underperforming market by {round(abs(diff_score), 1)} points\n"))
  }

  diff_dy <- comparison$portfolio_stats$mean_dy -
             comparison$market_stats$mean_dy

  if (diff_dy > 0) {
    cat(glue("  ✅ Portfolio has {round(diff_dy, 2)}% higher average DY\n"))
  } else {
    cat(glue("  ⚠️  Portfolio has {round(abs(diff_dy), 2)}% lower average DY\n"))
  }

  cat("\n")
}

# ============================================================================
# ADVANCED PEER ANALYSIS - CLUSTERING AND SIMILARITY
# ============================================================================

#' Identify peers using clustering
#'
#' @param ticker Target FII ticker
#' @param all_data Data frame with FII metrics (from load_scores_for_analysis)
#' @param method Clustering method: "kmeans", "hierarchical", "dbscan"
#' @param n_clusters Number of clusters (for kmeans/hierarchical)
#' @param features Variables to use for clustering
#' @return Tibble with tickers from same cluster + distance
#' @export
identify_peers_clustering <- function(
  ticker,
  all_data,
  method = "kmeans",
  n_clusters = 5,
  features = c("patrimonio_liquido", "dy_12m", "pvp", "volatility")
) {

  # Validate features
  missing_features <- setdiff(features, names(all_data))
  if (length(missing_features) > 0) {
    stop(glue("Missing features in data: {paste(missing_features, collapse=', ')}"))
  }

  # Filter and normalize data
  cluster_data <- all_data %>%
    select(ticker, all_of(features)) %>%
    drop_na()

  if (!ticker %in% cluster_data$ticker) {
    stop(glue("Ticker {ticker} not found in data or has missing values"))
  }

  # Normalize features (z-score)
  cluster_matrix <- cluster_data %>%
    select(-ticker) %>%
    as.matrix() %>%
    scale()

  rownames(cluster_matrix) <- cluster_data$ticker

  # Apply clustering method
  if (method == "kmeans") {
    set.seed(42)
    cluster_result <- kmeans(cluster_matrix, centers = n_clusters, nstart = 25)
    clusters <- cluster_result$cluster

  } else if (method == "hierarchical") {
    dist_matrix <- dist(cluster_matrix)
    hc <- hclust(dist_matrix, method = "ward.D2")
    clusters <- cutree(hc, k = n_clusters)

  } else if (method == "dbscan") {
    if (!requireNamespace("dbscan", quietly = TRUE)) {
      stop("Package 'dbscan' needed for this method. Please install it.")
    }
    dist_matrix <- dist(cluster_matrix)
    db_result <- dbscan::dbscan(dist_matrix, eps = 0.5, minPts = 3)
    clusters <- db_result$cluster

  } else {
    stop(glue("Unknown clustering method: {method}"))
  }

  # Get target cluster
  target_cluster <- clusters[ticker]

  # Calculate distances to target
  target_vector <- cluster_matrix[ticker, ]
  distances <- apply(cluster_matrix, 1, function(x) {
    sqrt(sum((x - target_vector)^2))
  })

  # Return peers from same cluster
  result <- tibble(
    ticker = names(clusters),
    cluster = clusters,
    distance = distances
  ) %>%
    filter(cluster == target_cluster, ticker != !!ticker) %>%
    arrange(distance) %>%
    left_join(
      all_data %>% select(ticker, tipo_fii, dy_12m, pvp, total_score),
      by = "ticker"
    )

  return(result)
}

#' Calculate similarity score between two FIIs
#'
#' @param ticker1 First FII ticker
#' @param ticker2 Second FII ticker
#' @param all_data Data frame with FII metrics
#' @param features Variables to use for similarity calculation
#' @param weights Optional weights vector (same length as features)
#' @return Similarity score 0-100 (100 = identical)
#' @export
calculate_similarity_score <- function(
  ticker1,
  ticker2,
  all_data,
  features = c("dy_12m", "pvp", "patrimonio_liquido", "volatility"),
  weights = NULL
) {

  # Validate tickers exist
  if (!ticker1 %in% all_data$ticker) {
    stop(glue("Ticker {ticker1} not found in data"))
  }
  if (!ticker2 %in% all_data$ticker) {
    stop(glue("Ticker {ticker2} not found in data"))
  }

  # Validate features
  missing_features <- setdiff(features, names(all_data))
  if (length(missing_features) > 0) {
    stop(glue("Missing features in data: {paste(missing_features, collapse=', ')}"))
  }

  # Set equal weights if not provided
  if (is.null(weights)) {
    weights <- rep(1, length(features))
  } else if (length(weights) != length(features)) {
    stop("weights must be same length as features")
  }

  # Normalize weights to sum to 1
  weights <- weights / sum(weights)

  # Get feature data
  features_data <- all_data %>%
    select(ticker, all_of(features)) %>%
    filter(ticker %in% c(ticker1, ticker2))

  # Check for missing values
  if (any(is.na(features_data %>% select(-ticker)))) {
    warning("Missing values found in features, using na.rm=TRUE")
  }

  # Normalize features (z-score) using full dataset
  feature_matrix <- all_data %>%
    select(all_of(features)) %>%
    as.matrix() %>%
    scale()

  # Get vectors for the two tickers
  ticker1_idx <- which(all_data$ticker == ticker1)
  ticker2_idx <- which(all_data$ticker == ticker2)

  vec1 <- feature_matrix[ticker1_idx, ]
  vec2 <- feature_matrix[ticker2_idx, ]

  # Calculate weighted Euclidean distance
  weighted_diff <- sqrt(sum(weights * (vec1 - vec2)^2))

  # Convert distance to similarity score (0-100)
  # Max possible distance with unit weights is sqrt(n_features)
  max_distance <- sqrt(sum(weights))
  similarity <- 100 * (1 - min(weighted_diff / (max_distance * 2), 1))

  return(similarity)
}

#' Find most similar FIIs to a target ticker
#'
#' @param ticker Target FII ticker
#' @param all_data Data frame with FII metrics
#' @param top_n Number of similar FIIs to return
#' @return Tibble with top N most similar FIIs and scores
#' @export
find_most_similar_fiis <- function(ticker, all_data, top_n = 5) {

  if (!ticker %in% all_data$ticker) {
    stop(glue("Ticker {ticker} not found in data"))
  }

  # Get target type for filtering
  target_type <- all_data %>%
    filter(ticker == !!ticker) %>%
    pull(tipo_fii)

  # Filter same segment
  segment_data <- all_data %>%
    filter(str_detect(tipo_fii, !!target_type), ticker != !!ticker)

  # Calculate similarity to all FIIs in segment
  similarities <- segment_data$ticker %>%
    map_dbl(~calculate_similarity_score(ticker, .x, all_data))

  result <- tibble(
    ticker = segment_data$ticker,
    similarity_score = similarities
  ) %>%
    arrange(desc(similarity_score)) %>%
    head(top_n) %>%
    left_join(
      all_data %>% select(ticker, tipo_fii, dy_12m, pvp, total_score),
      by = "ticker"
    )

  return(result)
}

# ============================================================================
# MULTIDIMENSIONAL COMPARISON
# ============================================================================

#' Compare FII with peers across multiple dimensions
#'
#' @param ticker Target FII ticker
#' @param peers Vector of peer tickers (NULL = auto-detect using clustering)
#' @param all_data Data frame with FII metrics
#' @param dimensions Dimensions to compare: "quality", "income", "valuation", "risk"
#' @return Tibble with metrics by dimension for ticker + peers
#' @export
compare_multidimensional <- function(
  ticker,
  peers = NULL,
  all_data,
  dimensions = c("quality", "income", "valuation", "risk")
) {

  # Auto-detect peers if not provided
  if (is.null(peers)) {
    peer_data <- identify_peers_clustering(
      ticker,
      all_data,
      method = "kmeans",
      n_clusters = 5
    )
    peers <- peer_data$ticker[1:min(5, nrow(peer_data))]
  }

  # Validate dimensions
  available_dims <- c("quality", "income", "valuation", "risk")
  invalid_dims <- setdiff(dimensions, available_dims)
  if (length(invalid_dims) > 0) {
    stop(glue("Invalid dimensions: {paste(invalid_dims, collapse=', ')}"))
  }

  # Combine target and peers
  all_tickers <- c(ticker, peers)

  # Get comparison data
  comparison_data <- all_data %>%
    filter(ticker %in% all_tickers) %>%
    select(ticker, tipo_fii, all_of(dimensions), total_score, dy_12m, pvp) %>%
    mutate(is_target = ticker == !!ticker)

  # Calculate dimension statistics
  dimension_stats <- comparison_data %>%
    summarise(
      across(all_of(dimensions),
             list(
               mean = ~mean(.x, na.rm = TRUE),
               median = ~median(.x, na.rm = TRUE),
               sd = ~sd(.x, na.rm = TRUE)
             ),
             .names = "{.col}_{.fn}")
    )

  # Add percentile ranks
  comparison_data <- comparison_data %>%
    mutate(
      across(all_of(dimensions),
             ~percent_rank(.x) * 100,
             .names = "{.col}_percentile")
    )

  result <- list(
    ticker = ticker,
    peers = peers,
    comparison_data = comparison_data,
    dimension_stats = dimension_stats,
    dimensions = dimensions
  )

  return(result)
}

# ============================================================================
# OUTLIER DETECTION
# ============================================================================

#' Detect outliers in a segment
#'
#' @param ticker Target FII ticker
#' @param segment_data Data frame with segment FIIs
#' @param indicators Indicators to check for outliers
#' @param method Outlier detection method: "iqr", "zscore", "isolation_forest"
#' @return List with positive/negative outliers + justification
#' @export
detect_outliers_segment <- function(
  ticker,
  segment_data,
  indicators = c("dy_12m", "pvp", "patrimonio_liquido"),
  method = "iqr"
) {

  if (!ticker %in% segment_data$ticker) {
    stop(glue("Ticker {ticker} not found in segment data"))
  }

  # Validate indicators
  missing_indicators <- setdiff(indicators, names(segment_data))
  if (length(missing_indicators) > 0) {
    stop(glue("Missing indicators in data: {paste(missing_indicators, collapse=', ')}"))
  }

  # Get target values
  target_values <- segment_data %>%
    filter(ticker == !!ticker) %>%
    select(all_of(indicators))

  outlier_results <- list()

  for (indicator in indicators) {
    values <- segment_data[[indicator]]
    target_value <- target_values[[indicator]]

    # Skip if missing
    if (is.na(target_value)) {
      outlier_results[[indicator]] <- list(
        is_outlier = FALSE,
        direction = NA,
        justification = "Missing data"
      )
      next
    }

    if (method == "iqr") {
      # IQR method
      q1 <- quantile(values, 0.25, na.rm = TRUE)
      q3 <- quantile(values, 0.75, na.rm = TRUE)
      iqr <- q3 - q1

      lower_bound <- q1 - 1.5 * iqr
      upper_bound <- q3 + 1.5 * iqr

      is_outlier <- target_value < lower_bound | target_value > upper_bound

      if (is_outlier) {
        if (target_value < lower_bound) {
          direction <- "negative"
          justification <- glue("{indicator} = {round(target_value, 2)} is below lower bound ({round(lower_bound, 2)})")
        } else {
          direction <- "positive"
          justification <- glue("{indicator} = {round(target_value, 2)} is above upper bound ({round(upper_bound, 2)})")
        }
      } else {
        direction <- "normal"
        justification <- glue("{indicator} = {round(target_value, 2)} is within normal range [{round(lower_bound, 2)}, {round(upper_bound, 2)}]")
      }

    } else if (method == "zscore") {
      # Z-score method (threshold = 3)
      mean_val <- mean(values, na.rm = TRUE)
      sd_val <- sd(values, na.rm = TRUE)

      z_score <- (target_value - mean_val) / sd_val
      is_outlier <- abs(z_score) > 3

      if (is_outlier) {
        direction <- ifelse(z_score > 0, "positive", "negative")
        justification <- glue("{indicator} has z-score of {round(z_score, 2)} (threshold = 3)")
      } else {
        direction <- "normal"
        justification <- glue("{indicator} has z-score of {round(z_score, 2)} (within ±3)")
      }

    } else if (method == "isolation_forest") {
      stop("isolation_forest method not yet implemented. Use 'iqr' or 'zscore'.")

    } else {
      stop(glue("Unknown method: {method}"))
    }

    outlier_results[[indicator]] <- list(
      value = target_value,
      is_outlier = is_outlier,
      direction = direction,
      justification = justification
    )
  }

  # Summarize
  positive_outliers <- outlier_results[
    sapply(outlier_results, function(x) x$direction == "positive")
  ]

  negative_outliers <- outlier_results[
    sapply(outlier_results, function(x) x$direction == "negative")
  ]

  result <- list(
    ticker = ticker,
    method = method,
    all_results = outlier_results,
    positive_outliers = positive_outliers,
    negative_outliers = negative_outliers,
    summary = glue(
      "{length(positive_outliers)} positive outliers, ",
      "{length(negative_outliers)} negative outliers"
    )
  )

  return(result)
}

# ============================================================================
# VISUALIZATIONS
# ============================================================================

#' Generate radar chart for multidimensional comparison
#'
#' @param ticker Target FII ticker
#' @param peers Vector of peer tickers (NULL = auto-detect)
#' @param all_data Data frame with FII metrics
#' @param dimensions Dimensions to plot
#' @param save_path Optional path to save PNG file
#' @return ggplot object
#' @export
generate_radar_chart <- function(
  ticker,
  peers = NULL,
  all_data,
  dimensions = c("quality", "income", "valuation", "risk"),
  save_path = NULL
) {

  # Get comparison data
  comp_data <- compare_multidimensional(ticker, peers, all_data, dimensions)

  # Prepare data for radar chart
  radar_data <- comp_data$comparison_data %>%
    select(ticker, is_target, all_of(dimensions)) %>%
    pivot_longer(cols = all_of(dimensions), names_to = "dimension", values_to = "score") %>%
    mutate(
      dimension = str_to_title(dimension),
      ticker_label = ifelse(is_target, glue("{ticker} (Target)"), ticker)
    )

  # Create radar chart using ggplot2
  p <- ggplot(radar_data, aes(x = dimension, y = score, group = ticker_label, color = ticker_label)) +
    geom_polygon(aes(fill = ticker_label), alpha = 0.2, linewidth = 1) +
    geom_point(size = 3) +
    coord_polar() +
    scale_y_continuous(limits = c(0, 100)) +
    labs(
      title = glue("Multidimensional Comparison: {ticker}"),
      subtitle = "Dimensions: Quality, Income, Valuation, Risk",
      x = NULL,
      y = "Score (0-100)",
      color = "FII",
      fill = "FII"
    ) +
    theme_minimal() +
    theme(
      legend.position = "bottom",
      axis.text.x = element_text(size = 11, face = "bold"),
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, size = 10)
    )

  # Save if path provided
  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 10, height = 8, dpi = 300)
    cat(glue("Radar chart saved to: {save_path}\n"))
  }

  return(p)
}

#' Generate scatter matrix (pairs plot) for segment
#'
#' @param segment_data Data frame with segment FIIs
#' @param variables Variables to plot
#' @param highlight_ticker Optional ticker to highlight
#' @return ggplot object
#' @export
generate_scatter_matrix <- function(
  segment_data,
  variables = c("dy_12m", "pvp", "patrimonio_liquido", "volatility"),
  highlight_ticker = NULL
) {

  # Validate variables
  missing_vars <- setdiff(variables, names(segment_data))
  if (length(missing_vars) > 0) {
    stop(glue("Missing variables in data: {paste(missing_vars, collapse=', ')}"))
  }

  # Prepare data
  plot_data <- segment_data %>%
    select(ticker, all_of(variables))

  # Add highlight flag
  if (!is.null(highlight_ticker)) {
    plot_data <- plot_data %>%
      mutate(is_highlight = ticker == highlight_ticker)
  } else {
    plot_data$is_highlight <- FALSE
  }

  # Create pairs plot using GGally if available, otherwise basic ggplot
  if (requireNamespace("GGally", quietly = TRUE)) {
    p <- GGally::ggpairs(
      plot_data,
      columns = variables,
      mapping = aes(color = is_highlight, alpha = ifelse(is_highlight, 1, 0.5)),
      upper = list(continuous = "cor"),
      lower = list(continuous = "points"),
      diag = list(continuous = "densityDiag"),
      title = "Scatter Matrix - Segment Analysis"
    ) +
    theme_minimal()

  } else {
    # Fallback: simple scatter plot of first two variables
    warning("Package 'GGally' not available. Creating simple scatter plot.")

    p <- ggplot(plot_data, aes_string(x = variables[1], y = variables[2])) +
      geom_point(aes(color = is_highlight, size = is_highlight, alpha = is_highlight)) +
      scale_color_manual(values = c("grey60", "red")) +
      scale_size_manual(values = c(2, 4)) +
      scale_alpha_manual(values = c(0.5, 1)) +
      labs(
        title = "Scatter Plot - Segment Analysis",
        subtitle = glue("{variables[1]} vs {variables[2]}")
      ) +
      theme_minimal() +
      theme(legend.position = "none")
  }

  return(p)
}

#' Generate comparison heatmap
#'
#' @param tickers Vector of tickers to compare
#' @param all_data Data frame with FII metrics
#' @param metrics Metrics to include in heatmap
#' @return ggplot object
#' @export
generate_comparison_heatmap <- function(
  tickers,
  all_data,
  metrics = c("dy_12m", "pvp", "total_score")
) {

  # Filter and select data
  heatmap_data <- all_data %>%
    filter(ticker %in% tickers) %>%
    select(ticker, all_of(metrics))

  # Calculate z-scores for each metric
  heatmap_data_z <- heatmap_data %>%
    mutate(
      across(all_of(metrics),
             ~scale(.x)[,1],
             .names = "{.col}_z")
    ) %>%
    select(ticker, ends_with("_z")) %>%
    pivot_longer(cols = ends_with("_z"), names_to = "metric", values_to = "z_score") %>%
    mutate(metric = str_remove(metric, "_z"))

  # Create heatmap
  p <- ggplot(heatmap_data_z, aes(x = metric, y = ticker, fill = z_score)) +
    geom_tile(color = "white", linewidth = 0.5) +
    geom_text(aes(label = round(z_score, 2)), color = "black", size = 3) +
    scale_fill_gradient2(
      low = "red",
      mid = "white",
      high = "darkgreen",
      midpoint = 0,
      name = "Z-Score"
    ) +
    labs(
      title = "FII Comparison Heatmap",
      subtitle = "Standardized scores (z-scores) by metric",
      x = "Metric",
      y = "Ticker"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, size = 10)
    )

  return(p)
}
