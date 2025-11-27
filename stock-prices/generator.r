#!/usr/bin/env Rscript

# --- 1. Load Libraries ---
suppressPackageStartupMessages({
  if (!require("quantmod")) stop("Package 'quantmod' is required.")
  if (!require("dplyr")) stop("Package 'dplyr' is required.")
  if (!require("tools")) stop("Package 'tools' is required.") # For file path handling
})

# --- 2. Helper Functions ---
parse_date_arg <- function(date_str) {
  d <- tryCatch({
    as.Date(date_str)
  }, error = function(e) { NA })
  
  if (is.na(d)) stop(paste("Invalid date format:", date_str, "- Please use yyyy-mm-dd or yyyy/mm/dd"))
  return(d)
}

# --- 3. Custom Argument Parsing ---
# We need to extract '-f' and its value, then leave the rest as positional args
raw_args <- commandArgs(trailingOnly = TRUE)
positional_args <- c()
output_target <- NULL

skip_next <- FALSE
for (i in seq_along(raw_args)) {
  if (skip_next) {
    skip_next <- FALSE
    next
  }
  
  arg <- raw_args[i]
  
  if (arg == "-f") {
    if (i + 1 > length(raw_args)) stop("Error: Flag -f requires a filename or directory path.")
    output_target <- raw_args[i + 1]
    skip_next <- TRUE
  } else {
    positional_args <- c(positional_args, arg)
  }
}

# --- 4. Validate Positional Arguments ---
if (length(positional_args) < 1) {
  stop("Error: Stock symbol argument is missing.\nUsage: Rscript get_stock_v3.R <SYMBOL> [START] [END] [-f OUTPUT]")
}

# Symbol
symbol <- toupper(positional_args[1])

# End Date
if (length(positional_args) >= 3) {
  end_date <- parse_date_arg(positional_args[3])
} else {
  end_date <- Sys.Date()
}

# Start Date
if (length(positional_args) >= 2) {
  start_date <- parse_date_arg(positional_args[2])
} else {
  start_date <- seq(end_date, length = 2, by = "-1 years")[2]
}

# --- 5. Fetch and Process Data ---
tryCatch({
  cat(sprintf("Fetching data for %s (%s to %s)...\n", symbol, start_date, end_date))
  
  raw_data <- getSymbols(symbol, src = "yahoo", from = start_date, to = end_date, auto.assign = FALSE)
  adj_data <- adjustOHLC(raw_data, use.Adjusted = TRUE)
  
  df <- as.data.frame(adj_data)
  df$date <- row.names(df)
  
  final_df <- df %>%
    select(
      date,
      open   = matches("\\.Open$"),
      close  = matches("\\.Close$"),
      high   = matches("\\.High$"),
      low    = matches("\\.Low$"),
      volume = matches("\\.Volume$")
    )
  
  final_df$date <- as.Date(final_df$date)
  price_cols <- c("open", "close", "high", "low")
  final_df[price_cols] <- lapply(final_df[price_cols], round, 2)
  
  # --- 6. Handle Output Logic ---
  # Construct the default filename
  default_filename <- sprintf("%s-%s-to-%s.csv", symbol, start_date, end_date)
  
  final_path <- default_filename # Default case
  
  if (!is.null(output_target)) {
    # Check if the target is an existing directory
    if (dir.exists(output_target)) {
      # It is a folder: Append default filename to this folder path
      final_path <- file.path(output_target, default_filename)
      cat(sprintf("Output target is a folder. Saving to: %s\n", final_path))
    } else {
      # It is not an existing folder: Treat it as the custom filename
      # Optional: Create parent directories if they don't exist
      dir_name <- dirname(output_target)
      if (dir_name != "." && !dir.exists(dir_name)) {
        dir.create(dir_name, recursive = TRUE)
      }
      final_path <- output_target
    }
  }
  
  # --- 7. Export ---
  write.csv(final_df, final_path, row.names = FALSE)
  cat(sprintf("Success: Data saved to '%s' (%d rows)\n", final_path, nrow(final_df)))
  
}, error = function(e) {
  cat("Error processing data: ", conditionMessage(e), "\n")
})
