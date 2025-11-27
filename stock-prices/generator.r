#!/usr/bin/env Rscript

# --- 1. Load Libraries (Suppressing startup messages for cleaner CLI output) ---
suppressPackageStartupMessages({
  if (!require("quantmod")) stop("Package 'quantmod' is required. Run install.packages('quantmod')")
  if (!require("dplyr")) stop("Package 'dplyr' is required. Run install.packages('dplyr')")
})

# --- 2. Helper Function for Date Parsing ---
# Handles the yyyy/mm/dd format specifically
parse_date_arg <- function(date_str) {
  tryCatch({
    as.Date(date_str, format = "%Y/%m/%d")
  }, error = function(e) {
    stop(paste("Invalid date format:", date_str, "- Please use yyyy/mm/dd"))
  })
}

# --- 3. Process Command Line Arguments ---
args <- commandArgs(trailingOnly = TRUE)

# Validation: Must have at least the stock symbol
if (length(args) < 1) {
  stop("Error: Stock symbol argument is missing.\nUsage: Rscript get_stock.R <SYMBOL> [START_DATE] [END_DATE]")
}

# -> 1st Parameter: Stock Symbol
symbol <- toupper(args[1])

# -> 3rd Parameter: End Date (Logic: Defaults to NOW if not provided)
if (length(args) >= 3) {
  end_date <- parse_date_arg(args[3])
} else {
  end_date <- Sys.Date()
}

# -> 2nd Parameter: Start Date 
# (Logic: Defaults to 1 year prior to End Date if not provided)
if (length(args) >= 2) {
  start_date <- parse_date_arg(args[2])
} else {
  # Calculate exactly one year prior using seq() to handle leap years correctly
  start_date <- seq(end_date, length = 2, by = "-1 years")[2]
}

# --- 4. Execution Info ---
cat(sprintf("Config: Symbol=%s | Start=%s | End=%s\n", symbol, start_date, end_date))

# --- 5. Fetch Data ---
tryCatch({
  # fetch data (auto.assign=FALSE ensures it returns the data to our variable rather than the global env)
  stock_data <- getSymbols(symbol, src = "yahoo", from = start_date, to = end_date, auto.assign = FALSE)
  
  # --- 6. Process Data Frame ---
  # Convert xts to dataframe
  df <- as.data.frame(stock_data)
  df$date <- row.names(df)
  
  # Select and Rename columns
  # We look for the column ending in ".Close" (e.g., AAPL.Close)
  final_df <- df %>%
    select(date, matches("\\.Close$")) 
  
  # Rename the price column dynamically (since it currently has the ticker name in it)
  colnames(final_df) <- c("date", "price (USD)")
  
  # Format date to standard yyyy-mm-dd (or keep strictly as source if preferred)
  final_df$date <- as.Date(final_df$date)
  
  # Round prices
  final_df$`price (USD)` <- round(final_df$`price (USD)`, 2)
  
  # --- 7. Export to CSV ---
  filename <- sprintf("%s_stock_%s_to_%s.csv", symbol, start_date, end_date)
  write.csv(final_df, filename, row.names = FALSE)
  
  cat(sprintf("Success: Data saved to '%s' (%d rows)\n", filename, nrow(final_df)))
  
}, error = function(e) {
  cat("Error fetching data: ", conditionMessage(e), "\n")
})
