# New Advanced Peer Analysis Functions

Added to `/Users/gsposito/Projects/fii_manager/R/analysis/fii_comparison.R`

## Summary
- **Total lines added:** ~597 lines
- **New exported functions:** 8
- **Existing functions preserved:** 4 (compare_with_peers, print_comparison_report, portfolio_vs_market, print_portfolio_vs_market)
- **Total exported functions:** 12

---

## New Functions

### 1. CLUSTERING DE PARES

#### `identify_peers_clustering(ticker, all_data, method = "kmeans", n_clusters = 5, features = c(...))`
**Purpose:** Identify peer FIIs using machine learning clustering algorithms

**Methods:**
- `"kmeans"` - K-means clustering (default)
- `"hierarchical"` - Hierarchical clustering with Ward's method
- `"dbscan"` - Density-based clustering (requires `dbscan` package)

**Returns:** Tibble with:
- ticker
- cluster (cluster number)
- distance (Euclidean distance to target)
- tipo_fii, dy_12m, pvp, total_score

**Features used:** patrimonio_liquido, dy_12m, pvp, volatility (customizable)

---

### 2. SIMILARIDADE

#### `calculate_similarity_score(ticker1, ticker2, all_data, features = c(...), weights = NULL)`
**Purpose:** Calculate similarity score between two FIIs using weighted distance

**Parameters:**
- `features` - Variables to compare
- `weights` - Optional weight vector (defaults to equal weights)

**Returns:** Score 0-100 (100 = identical FIIs)

**Algorithm:**
1. Normalize all features using z-scores
2. Calculate weighted Euclidean distance
3. Convert distance to similarity percentage

---

#### `find_most_similar_fiis(ticker, all_data, top_n = 5)`
**Purpose:** Find the N most similar FIIs to a target (same segment)

**Returns:** Tibble with:
- ticker
- similarity_score (0-100)
- tipo_fii, dy_12m, pvp, total_score

**Use case:** "Which FIIs are most comparable to HGLG11?"

---

### 3. COMPARAÇÃO MULTIDIMENSIONAL

#### `compare_multidimensional(ticker, peers = NULL, all_data, dimensions = c(...))`
**Purpose:** Compare FII with peers across multiple scoring dimensions

**Dimensions:** quality, income, valuation, risk

**Features:**
- Auto-detects peers using clustering if `peers = NULL`
- Calculates percentile ranks within comparison group
- Provides dimension statistics (mean, median, sd)

**Returns:** List with:
- ticker (target)
- peers (vector of peer tickers)
- comparison_data (tibble with scores and percentiles)
- dimension_stats (summary statistics)
- dimensions (which dimensions analyzed)

---

### 4. DETECÇÃO DE OUTLIERS

#### `detect_outliers_segment(ticker, segment_data, indicators = c(...), method = "iqr")`
**Purpose:** Identify if a FII is an outlier in its segment

**Methods:**
- `"iqr"` - Interquartile range method (default, threshold = 1.5 * IQR)
- `"zscore"` - Z-score method (threshold = 3)
- `"isolation_forest"` - Not yet implemented

**Returns:** List with:
- all_results (detailed results per indicator)
- positive_outliers (significantly above segment)
- negative_outliers (significantly below segment)
- summary (text summary)

**Each result includes:**
- value (actual value)
- is_outlier (TRUE/FALSE)
- direction ("positive", "negative", "normal")
- justification (text explanation)

---

### 5. VISUALIZAÇÕES

#### `generate_radar_chart(ticker, peers = NULL, all_data, dimensions = c(...), save_path = NULL)`
**Purpose:** Create radar/spider chart comparing FII dimensions

**Features:**
- Compares quality, income, valuation, risk scores
- Overlays target FII with up to 5 peers
- Auto-detects peers if not provided
- Can save to PNG file

**Returns:** ggplot object (can be further customized)

---

#### `generate_scatter_matrix(segment_data, variables = c(...), highlight_ticker = NULL)`
**Purpose:** Create scatter matrix (pairs plot) showing variable relationships

**Features:**
- Uses `GGally::ggpairs()` if available
- Shows correlations in upper triangle
- Shows scatter plots in lower triangle
- Highlights target ticker if provided
- Falls back to simple scatter plot if GGally not installed

**Returns:** ggplot object

**Use case:** Understand correlations between dy_12m, pvp, patrimonio_liquido, volatility

---

#### `generate_comparison_heatmap(tickers, all_data, metrics = c(...))`
**Purpose:** Create heatmap comparing multiple FIIs

**Features:**
- Uses z-scores for standardization
- Color gradient: red (below average) → white (average) → green (above average)
- Shows z-score values in cells

**Returns:** ggplot object

**Use case:** Compare portfolio holdings side-by-side

---

## Example Usage

```r
# Load data
source("R/analysis/fii_comparison.R")
scores <- load_scores_for_analysis()

# 1. Find peers using clustering
peers <- identify_peers_clustering("HGLG11", scores, method = "kmeans", n_clusters = 5)
head(peers)

# 2. Find most similar FIIs
similar <- find_most_similar_fiis("HGLG11", scores, top_n = 10)
print(similar)

# 3. Calculate similarity between two specific FIIs
similarity <- calculate_similarity_score("HGLG11", "XPLG11", scores)
cat("Similarity:", similarity, "%\n")

# 4. Multidimensional comparison
comp <- compare_multidimensional("HGLG11", peers = c("XPLG11", "VISC11", "GGRC11"), scores)
print(comp$comparison_data)

# 5. Detect outliers
outliers <- detect_outliers_segment(
  "HGLG11",
  scores %>% filter(str_detect(tipo_fii, "Logística")),
  indicators = c("dy_12m", "pvp", "patrimonio_liquido"),
  method = "iqr"
)
print(outliers$summary)
print(outliers$positive_outliers)

# 6. Generate radar chart
p <- generate_radar_chart("HGLG11", peers = NULL, scores)
print(p)
# Save to file
generate_radar_chart("HGLG11", peers = NULL, scores, save_path = "hglg11_radar.png")

# 7. Generate scatter matrix
segment_data <- scores %>% filter(str_detect(tipo_fii, "Logística"))
p <- generate_scatter_matrix(segment_data, highlight_ticker = "HGLG11")
print(p)

# 8. Generate heatmap
my_portfolio <- c("HGLG11", "XPLG11", "VISC11", "GGRC11", "MXRF11")
p <- generate_comparison_heatmap(my_portfolio, scores, metrics = c("dy_12m", "pvp", "total_score"))
print(p)
```

---

## Technical Details

### Data Normalization
All clustering and similarity functions normalize features using z-scores to ensure fair comparison across different scales.

### Dependencies
- **Required:** tidyverse, ggplot2, glue
- **Optional:** GGally (for scatter matrix), dbscan (for DBSCAN clustering)

### Compatibility
- All existing functions preserved
- All new functions use `@export` roxygen2 tag
- Follows tidyverse conventions
- Returns ggplot objects (not rendered plots)
- Handles missing data gracefully with warnings

### Performance
- Clustering uses `set.seed(42)` for reproducibility
- K-means uses `nstart = 25` for stability
- Hierarchical clustering uses Ward's method for balanced clusters
