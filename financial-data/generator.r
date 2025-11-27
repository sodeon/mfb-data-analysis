#!/usr/bin/env Rscript

# -------------------------------------------------------------------------
# Setup & Libraries
# -------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(optparse)
  library(simfinapi)
  library(lubridate)
  library(dplyr)
  library(readr)
  library(fs)
  library(stringr)
})

# -------------------------------------------------------------------------
# Argument Parsing
# -------------------------------------------------------------------------
option_list <- list(
  make_option(c("-f", "--folder"), type = "character", default = ".", 
              help = "Target Folder for output files (defaults to current dir)"),
  make_option(c("-k", "--keyfile"), type = "character", default = NULL, 
              help = "Path to file containing API Key")
)

parser <- OptionParser(usage = "%prog [options] SYMBOL [START_DATE] [END_DATE]", 
                       option_list = option_list)

arguments <- parse_args(parser, positional_arguments = TRUE)
opt <- arguments$options
args <- arguments$args

# -------------------------------------------------------------------------
# Input Validation & Defaults
# -------------------------------------------------------------------------

if (length(args) < 1) {
  stop("Error: Stock Symbol is required.\nUsage: Rscript get_financials_quarterly.R AAPL [start] [end]", call. = FALSE)
}
symbol <- toupper(args[1])

# Handle Dates
if (length(args) >= 3) {
  end_date <- tryCatch(ymd(args[3]), error = function(e) ymd(gsub("/", "-", args[3])))
} else {
  end_date <- Sys.Date()
}

if (length(args) >= 2) {
  start_date <- tryCatch(ymd(args[2]), error = function(e) ymd(gsub("/", "-", args[2])))
} else {
  start_date <- end_date - years(1)
}

if (is.na(start_date) || is.na(end_date)) {
  stop("Error: Invalid date format. Use YYYY-MM-DD.", call. = FALSE)
}

# Handle API Key
api_key <- NULL
if (!is.null(opt$keyfile)) {
  if (file.exists(opt$keyfile)) {
    api_key <- trimws(read_file(opt$keyfile))
  } else {
    stop(paste("Error: API key file not found at", opt$keyfile), call. = FALSE)
  }
} else {
  if (interactive()) {
    api_key <- readline(prompt = "Please enter your SimFin API Key: ")
  } else {
    cat("Enter SimFin API Key: ")
    api_key <- readLines("stdin", n = 1)
  }
}

if (identical(api_key, "") || is.na(api_key)) {
  stop("Error: API Key is required.", call. = FALSE)
}

sfa_set_api_key(api_key)

# -------------------------------------------------------------------------
# Cache Configuration
# -------------------------------------------------------------------------
os_sys <- Sys.info()[['sysname']]
cache_dir <- NULL

if (os_sys == "Linux") {
  cache_dir <- file.path("/tmp", "simfin_cache")
} else if (os_sys == "Windows") {
  cache_dir <- file.path(Sys.getenv("TEMP"), "simfin_cache")
} else {
  cache_dir <- file.path(tempdir(), "simfin_cache")
}

if (!dir_exists(cache_dir)) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
}

sfa_set_cache_dir(cache_dir)
cat(sprintf("Cache enabled at: %s\n", cache_dir))

# -------------------------------------------------------------------------
# Handle Output Directory
# -------------------------------------------------------------------------
output_dir <- opt$folder
if (!dir_exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  cat(sprintf("Created output directory: %s\n", output_dir))
}

# -------------------------------------------------------------------------
# Core Logic
# -------------------------------------------------------------------------

process_statement <- function(ticker, type_code, type_label, s_date, e_date, out_dir) {
  
  cat(sprintf("\n--- Processing %s (%s) ---\n", type_label, type_code))
  
  # 1. Fetch Quarterly Data
  data <- tryCatch({
    sfa_load_statements(
      ticker = ticker, 
      statements = type_code, 
      period = c("q1", "q2", "q3", "q4"), 
      start = as.Date(s_date), 
      end = as.Date(e_date)
    )
  }, error = function(e) {
    cat(paste("API Error:", e$message, "\n"))
    return(NULL)
  })
  
  if (is.null(data) || nrow(data) == 0) {
    cat(sprintf("No data returned for %s in this range.\n", type_label))
    return(NULL)
  }
  
  # 2. Normalize and Sort
  date_col <- grep("(report|publish)?_?date", names(data), ignore.case = TRUE, value = TRUE)[1]
  
  if (is.na(date_col)) {
    cat("Warning: Could not find report date column. Skipping.\n")
    return(NULL)
  }
  
  # Add normalized date col, sort Descending, then remove helper
  df_sorted <- data %>%
    mutate(Date_Normalized = as.Date(get(date_col))) %>%
    arrange(desc(Date_Normalized)) %>%
    select(-Date_Normalized)
  
  # 3. Write Single File
  # Filename Format: {Symbol}-{Type}-{Start}-{End}.csv
  fname <- sprintf("%s-%s-%s-to-%s.csv", ticker, type_label, s_date, e_date)
  full_path <- file.path(out_dir, fname)
  
  write_csv(df_sorted, full_path)
  cat(sprintf("Saved: %s (%d quarters)\n", fname, nrow(df_sorted)))
}

# -------------------------------------------------------------------------
# Execution
# -------------------------------------------------------------------------

cat(sprintf("Fetching Quarterly Data for %s (Range: %s to %s)...\n", symbol, start_date, end_date))

# 1. Profit & Loss (pl) -> Output: IS (Income Statement)
process_statement(symbol, "pl", "IS", start_date, end_date, output_dir)

# 2. Balance Sheet (bs) -> Output: BS
process_statement(symbol, "bs", "BS", start_date, end_date, output_dir)

# 3. Cash Flow (cf) -> Output: CF
process_statement(symbol, "cf", "CF", start_date, end_date, output_dir)

# 4. Derived Ratios (derived) -> Output: RI
process_statement(symbol, "derived", "RI", start_date, end_date, output_dir)

cat("\nDone.\n")
