# persistence.R
# Padrões de persistência para arquivos RDS
# Backup automático, merge incremental, e save atômico

library(dplyr)
library(glue)

#' Save RDS with Backup
#'
#' Saves an RDS file with automatic backup of existing file.
#' Performs atomic write (temp file + rename) to prevent corruption.
#'
#' @param data Data to save
#' @param filepath Character, path to RDS file
#' @param backup_dir Character, directory for backups
#' @param logger Logger instance (optional)
#' @return Logical, TRUE if successful
#' @export
save_rds_with_backup <- function(data, filepath, backup_dir = "data_backup", logger = NULL) {
  # Cria diretório de backup se não existe
  if (!dir.exists(backup_dir)) {
    dir.create(backup_dir, recursive = TRUE)
  }

  # Backup do arquivo existente
  if (file.exists(filepath)) {
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    filename <- basename(filepath)
    backup_path <- file.path(backup_dir, glue("{tools::file_path_sans_ext(filename)}_{timestamp}.rds"))

    tryCatch({
      file.copy(filepath, backup_path, overwrite = FALSE)
      if (!is.null(logger)) {
        logger$info(glue("Backup created: {backup_path}"))
      }
    },
    error = function(e) {
      if (!is.null(logger)) {
        logger$warn(glue("Failed to create backup: {e$message}"))
      }
    })
  }

  # Save atômico: escreve em temp, depois rename
  temp_path <- paste0(filepath, ".tmp")

  tryCatch({
    saveRDS(data, temp_path, compress = TRUE)

    # Rename atômico
    file.rename(temp_path, filepath)

    if (!is.null(logger)) {
      logger$info(glue("Saved: {filepath} ({nrow(data)} rows)"))
    }

    TRUE
  },
  error = function(e) {
    # Limpa temp file se existir
    if (file.exists(temp_path)) {
      file.remove(temp_path)
    }

    if (!is.null(logger)) {
      logger$error(glue("Failed to save {filepath}: {e$message}"))
    }

    stop(e)
  })
}

#' Load RDS Safely
#'
#' Loads an RDS file with error handling.
#'
#' @param filepath Character, path to RDS file
#' @param default Default value if file doesn't exist or fails to load
#' @param logger Logger instance (optional)
#' @return Loaded data or default
#' @export
load_rds_safe <- function(filepath, default = NULL, logger = NULL) {
  if (!file.exists(filepath)) {
    if (!is.null(logger)) {
      logger$debug(glue("File not found: {filepath}"))
    }
    return(default)
  }

  tryCatch({
    data <- readRDS(filepath)
    if (!is.null(logger)) {
      logger$debug(glue("Loaded: {filepath} ({nrow(data)} rows)"))
    }
    data
  },
  error = function(e) {
    if (!is.null(logger)) {
      logger$error(glue("Failed to load {filepath}: {e$message}"))
    }
    default
  })
}

#' Merge Incremental Data
#'
#' Merges new data with existing data using bind_rows + distinct.
#' Preserves historical data while adding new records.
#'
#' @param new_data Data frame with new data
#' @param existing_data Data frame with existing data (optional)
#' @param dedup_columns Character vector of columns for deduplication
#' @param logger Logger instance (optional)
#' @return Merged data frame
#' @export
merge_incremental <- function(new_data, existing_data = NULL, dedup_columns = NULL, logger = NULL) {
  if (is.null(existing_data) || nrow(existing_data) == 0) {
    if (!is.null(logger)) {
      logger$info(glue("No existing data - using new data only ({nrow(new_data)} rows)"))
    }
    return(new_data)
  }

  # Merge
  merged <- bind_rows(existing_data, new_data)

  # Deduplica
  if (!is.null(dedup_columns)) {
    before_count <- nrow(merged)
    merged <- merged %>%
      distinct(across(all_of(dedup_columns)), .keep_all = TRUE)
    after_count <- nrow(merged)

    if (!is.null(logger)) {
      removed <- before_count - after_count
      logger$info(glue("Deduplication: removed {removed} duplicates"))
    }
  } else {
    # Deduplica por todas as colunas
    before_count <- nrow(merged)
    merged <- distinct(merged)
    after_count <- nrow(merged)

    if (!is.null(logger)) {
      removed <- before_count - after_count
      if (removed > 0) {
        logger$info(glue("Deduplication: removed {removed} exact duplicates"))
      }
    }
  }

  if (!is.null(logger)) {
    new_count <- nrow(merged) - nrow(existing_data)
    logger$info(glue("Merge complete: {nrow(existing_data)} existing + {nrow(new_data)} new = {nrow(merged)} total ({new_count} net new)"))
  }

  merged
}

#' Save with Incremental Merge
#'
#' Convenience function that combines load, merge, and save.
#'
#' @param new_data Data frame with new data
#' @param filepath Character, path to RDS file
#' @param dedup_columns Character vector of columns for deduplication
#' @param backup_dir Character, directory for backups
#' @param logger Logger instance (optional)
#' @return Logical, TRUE if successful
#' @export
save_incremental <- function(new_data,
                              filepath,
                              dedup_columns = NULL,
                              backup_dir = "data_backup",
                              logger = NULL) {

  # Load existing
  existing <- load_rds_safe(filepath, default = NULL, logger = logger)

  # Merge
  merged <- merge_incremental(new_data, existing, dedup_columns, logger)

  # Save
  save_rds_with_backup(merged, filepath, backup_dir, logger)
}

#' Clean Old Backups
#'
#' Removes backup files older than specified days.
#'
#' @param backup_dir Character, directory with backups
#' @param keep_days Integer, keep backups from last N days
#' @param logger Logger instance (optional)
#' @return Integer, number of files removed
#' @export
clean_old_backups <- function(backup_dir = "data_backup", keep_days = 30, logger = NULL) {
  if (!dir.exists(backup_dir)) {
    return(0)
  }

  files <- list.files(backup_dir, pattern = "\\.rds$", full.names = TRUE)
  if (length(files) == 0) {
    return(0)
  }

  cutoff_date <- Sys.time() - (keep_days * 24 * 60 * 60)
  removed <- 0

  for (file in files) {
    mtime <- file.info(file)$mtime
    if (mtime < cutoff_date) {
      tryCatch({
        file.remove(file)
        removed <- removed + 1
        if (!is.null(logger)) {
          logger$debug(glue("Removed old backup: {basename(file)}"))
        }
      },
      error = function(e) {
        if (!is.null(logger)) {
          logger$warn(glue("Failed to remove {basename(file)}: {e$message}"))
        }
      })
    }
  }

  if (!is.null(logger) && removed > 0) {
    logger$info(glue("Cleaned {removed} old backups (older than {keep_days} days)"))
  }

  removed
}

#' Validate RDS Schema
#'
#' Validates that an RDS data frame has the expected columns and types.
#'
#' @param data Data frame to validate
#' @param expected_schema List with column names as keys and types as values
#' @param strict Logical, if TRUE fails on extra columns
#' @param logger Logger instance (optional)
#' @return Logical, TRUE if valid
#' @export
validate_rds_schema <- function(data, expected_schema, strict = FALSE, logger = NULL) {
  if (!is.data.frame(data)) {
    if (!is.null(logger)) {
      logger$error("Data is not a data frame")
    }
    return(FALSE)
  }

  # Verifica colunas obrigatórias
  missing_cols <- setdiff(names(expected_schema), names(data))
  if (length(missing_cols) > 0) {
    if (!is.null(logger)) {
      logger$error(glue("Missing required columns: {paste(missing_cols, collapse=', ')}"))
    }
    return(FALSE)
  }

  # Verifica colunas extras (se strict)
  if (strict) {
    extra_cols <- setdiff(names(data), names(expected_schema))
    if (length(extra_cols) > 0) {
      if (!is.null(logger)) {
        logger$error(glue("Unexpected columns: {paste(extra_cols, collapse=', ')}"))
      }
      return(FALSE)
    }
  }

  # Verifica tipos
  for (col_name in names(expected_schema)) {
    expected_type <- expected_schema[[col_name]]
    actual_type <- class(data[[col_name]])[1]

    # Mapeamento de tipos flexível
    type_match <- FALSE
    if (expected_type == "character" && actual_type == "character") {
      type_match <- TRUE
    } else if (expected_type == "numeric" && actual_type %in% c("numeric", "integer", "double")) {
      type_match <- TRUE
    } else if (expected_type == "integer" && actual_type %in% c("integer", "numeric")) {
      type_match <- TRUE
    } else if (expected_type == "Date" && actual_type == "Date") {
      type_match <- TRUE
    } else if (expected_type == "POSIXct" && actual_type %in% c("POSIXct", "POSIXt")) {
      type_match <- TRUE
    } else if (expected_type == "logical" && actual_type == "logical") {
      type_match <- TRUE
    }

    if (!type_match) {
      if (!is.null(logger)) {
        logger$error(glue("Column '{col_name}': expected {expected_type}, got {actual_type}"))
      }
      return(FALSE)
    }
  }

  if (!is.null(logger)) {
    logger$debug("Schema validation passed")
  }

  TRUE
}

#' Get File Size Human Readable
#'
#' @param filepath Character, path to file
#' @return Character, human readable size
#' @keywords internal
get_file_size <- function(filepath) {
  if (!file.exists(filepath)) {
    return("N/A")
  }

  size_bytes <- file.info(filepath)$size
  if (size_bytes < 1024) {
    return(glue("{size_bytes} B"))
  } else if (size_bytes < 1024^2) {
    return(glue("{round(size_bytes/1024, 1)} KB"))
  } else if (size_bytes < 1024^3) {
    return(glue("{round(size_bytes/1024^2, 1)} MB"))
  } else {
    return(glue("{round(size_bytes/1024^3, 1)} GB"))
  }
}
