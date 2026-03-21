#' FII Score Pipeline - Transform Layer
#'
#' This script runs as part of the data pipeline (after import, before analysis)
#' to calculate and persist FII scores.
#'
#' Pipeline flow:
#'   Import → data/*.rds (raw data)
#'   Transform → data/fii_scores.rds (calculated scores) ← THIS SCRIPT
#'   Analysis → uses pre-calculated scores (fast)
#'
#' @author Claude Code
#' @date 2026-03-20

library(tidyverse)
library(lubridate)
library(glue)

source("./R/transform/fii_data_sources.R", encoding = "UTF-8")
source("./R/transform/fii_indicators.R", encoding = "UTF-8")
source("./R/transform/fii_scoring.R", encoding = "UTF-8")

# ============================================================================
# MAIN PIPELINE FUNCTION
# ============================================================================

#' Run complete FII scoring pipeline
#'
#' Calculates scores for all FIIs and saves to data/fii_scores.rds
#' Also appends to historical tracking file
#'
#' @param tickers Vector of tickers or "all" for all available
#' @param include_statusinvest Fetch StatusInvest data (default: FALSE)
#' @param force Force recalculation even if recent scores exist
#' @return Tibble with calculated scores
#' @export
run_scoring_pipeline <- function(tickers = "all",
                                  include_statusinvest = FALSE,
                                  force = FALSE) {

  message("═══════════════════════════════════════════════════════════════")
  message("           FII SCORING PIPELINE - TRANSFORM LAYER")
  message("═══════════════════════════════════════════════════════════════\n")

  # Check if scores are recent and skip if not forced
  if (!force && file.exists("data/fii_scores.rds")) {
    existing_scores <- readRDS("data/fii_scores.rds")
    if ("calculated_at" %in% names(existing_scores)) {
      last_calc <- max(existing_scores$calculated_at, na.rm = TRUE)
      age_hours <- as.numeric(difftime(Sys.time(), last_calc, units = "hours"))

      if (age_hours < 24) {
        message(glue("ℹ️  Scores calculated {round(age_hours, 1)}h ago (< 24h)"))
        message("   Use force=TRUE to recalculate\n")
        return(existing_scores)
      }
    }
  }

  # 1. Load raw data
  message("📦 Loading raw data...")
  cache <- load_cached_data()
  message("   ✓ Loaded portfolio, quotations, income, fiis\n")

  # 2. Determine tickers to score
  if (length(tickers) == 1 && tickers == "all") {
    all_tickers <- unique(c(
      cache$portfolio$ticker,
      cache$fiis$ticker[!is.na(cache$fiis$ticker)]
    ))
    message(glue("📊 Found {length(all_tickers)} unique tickers\n"))
  } else {
    all_tickers <- tickers
    message(glue("📊 Scoring {length(all_tickers)} specified tickers\n"))
  }

  # 3. Calculate scores
  message("🧮 Calculating scores...")
  scores <- score_multiple_fiis(
    all_tickers,
    include_statusinvest = include_statusinvest
  )

  # 4. Add metadata
  scores <- scores %>%
    mutate(
      calculated_at = Sys.time(),
      data_version = format(Sys.Date(), "%Y%m%d"),
      pipeline_version = "1.0.0"
    )

  message(glue("\n✓ Calculated scores for {nrow(scores)} FIIs"))

  # 5. Save current scores
  message("\n💾 Saving scores...")
  saveRDS(scores, "data/fii_scores.rds")
  write_csv(scores, "data/fii_scores.csv")
  message("   ✓ Saved to data/fii_scores.{rds,csv}")

  # 6. Append to history (if exists)
  history_file <- "data/fii_scores_history.rds"
  if (file.exists(history_file)) {
    history <- readRDS(history_file)

    # Add new scores
    history <- bind_rows(history, scores) %>%
      arrange(ticker, desc(calculated_at))

    # Keep last 30 days of history per ticker
    history <- history %>%
      filter(calculated_at >= today() - days(30))

    saveRDS(history, history_file)
    message("   ✓ Appended to history (last 30 days)")
  } else {
    saveRDS(scores, history_file)
    message("   ✓ Created history file")
  }

  # 7. Summary statistics
  message("\n📊 Summary Statistics:")
  message(glue("   Mean score:      {round(mean(scores$total_score, na.rm=TRUE), 1)}"))
  message(glue("   Median score:    {round(median(scores$total_score, na.rm=TRUE), 1)}"))

  comprar <- sum(scores$recommendation == "COMPRAR", na.rm = TRUE)
  manter <- sum(scores$recommendation == "MANTER", na.rm = TRUE)
  observar <- sum(scores$recommendation == "OBSERVAR", na.rm = TRUE)
  evitar <- sum(scores$recommendation == "EVITAR", na.rm = TRUE)

  message("\n📈 Recommendations:")
  message(glue("   🟢 COMPRAR:   {comprar} ({round(comprar/nrow(scores)*100, 1)}%)"))
  message(glue("   🟡 MANTER:    {manter} ({round(manter/nrow(scores)*100, 1)}%)"))
  message(glue("   🟠 OBSERVAR:  {observar} ({round(observar/nrow(scores)*100, 1)}%)"))
  message(glue("   🔴 EVITAR:    {evitar} ({round(evitar/nrow(scores)*100, 1)}%)"))

  message("\n═══════════════════════════════════════════════════════════════")
  message("                   ✅ PIPELINE COMPLETED")
  message("═══════════════════════════════════════════════════════════════\n")

  return(scores)
}

# ============================================================================
# INCREMENTAL SCORING (for single ticker updates)
# ============================================================================

#' Update scores for specific tickers
#'
#' Useful for updating individual FIIs without full pipeline run
#'
#' @param tickers Vector of tickers to update
#' @param include_statusinvest Fetch StatusInvest data
#' @return Updated scores tibble
#' @export
update_scores_incremental <- function(tickers, include_statusinvest = FALSE) {
  message(glue("🔄 Updating scores for {length(tickers)} tickers..."))

  # Load existing scores
  if (file.exists("data/fii_scores.rds")) {
    all_scores <- readRDS("data/fii_scores.rds")
  } else {
    all_scores <- tibble()
  }

  # Calculate new scores
  new_scores <- score_multiple_fiis(tickers, include_statusinvest = include_statusinvest) %>%
    mutate(
      calculated_at = Sys.time(),
      data_version = format(Sys.Date(), "%Y%m%d"),
      pipeline_version = "1.0.0"
    )

  # Merge: remove old scores for these tickers, add new ones
  updated_scores <- all_scores %>%
    filter(!ticker %in% tickers) %>%
    bind_rows(new_scores) %>%
    arrange(desc(total_score))

  # Save
  saveRDS(updated_scores, "data/fii_scores.rds")
  write_csv(updated_scores, "data/fii_scores.csv")

  message(glue("✓ Updated {length(tickers)} tickers"))

  return(updated_scores)
}

# ============================================================================
# SCORE FRESHNESS CHECK
# ============================================================================

#' Check if scores need refresh
#'
#' @param max_age_hours Maximum age in hours before refresh needed
#' @return Logical - TRUE if refresh needed
#' @export
need_score_refresh <- function(max_age_hours = 24) {
  if (!file.exists("data/fii_scores.rds")) {
    return(TRUE)
  }

  scores <- readRDS("data/fii_scores.rds")

  if (!"calculated_at" %in% names(scores)) {
    return(TRUE)
  }

  last_calc <- max(scores$calculated_at, na.rm = TRUE)
  age_hours <- as.numeric(difftime(Sys.time(), last_calc, units = "hours"))

  return(age_hours > max_age_hours)
}

# ============================================================================
# HELPER: Load scores (with auto-refresh)
# ============================================================================

#' Load scores with automatic refresh if stale
#'
#' @param max_age_hours Maximum age before auto-refresh
#' @param auto_refresh Auto-refresh if stale (default: FALSE)
#' @return Scores tibble
#' @export
load_scores <- function(max_age_hours = 24, auto_refresh = FALSE) {
  if (!file.exists("data/fii_scores.rds")) {
    if (auto_refresh) {
      message("📊 No scores found, running pipeline...")
      return(run_scoring_pipeline())
    } else {
      stop("No scores file found. Run run_scoring_pipeline() first.")
    }
  }

  scores <- readRDS("data/fii_scores.rds")

  if (auto_refresh && need_score_refresh(max_age_hours)) {
    message("📊 Scores are stale, refreshing...")
    return(run_scoring_pipeline())
  }

  return(scores)
}

# ============================================================================
# SCORE HISTORY ANALYSIS
# ============================================================================

#' Get score history for a ticker
#'
#' @param ticker FII ticker
#' @return Tibble with historical scores
#' @export
get_score_history <- function(ticker) {
  if (!file.exists("data/fii_scores_history.rds")) {
    warning("No history file found")
    return(tibble())
  }

  history <- readRDS("data/fii_scores_history.rds")

  history %>%
    filter(ticker == !!ticker) %>%
    arrange(calculated_at) %>%
    select(ticker, calculated_at, total_score, quality, income,
           valuation, risk, recommendation)
}

#' Detect score changes
#'
#' @param min_change Minimum change to report (default: 5 points)
#' @return Tibble with FIIs that had significant score changes
#' @export
detect_score_changes <- function(min_change = 5) {
  if (!file.exists("data/fii_scores_history.rds")) {
    warning("No history file found")
    return(tibble())
  }

  history <- readRDS("data/fii_scores_history.rds")

  # Get latest and previous scores
  changes <- history %>%
    arrange(ticker, desc(calculated_at)) %>%
    group_by(ticker) %>%
    filter(n() >= 2) %>%
    summarise(
      latest_score = first(total_score),
      previous_score = nth(total_score, 2),
      latest_date = first(calculated_at),
      previous_date = nth(calculated_at, 2),
      change = latest_score - previous_score,
      change_pct = (change / previous_score) * 100
    ) %>%
    filter(abs(change) >= min_change) %>%
    arrange(desc(abs(change)))

  return(changes)
}
