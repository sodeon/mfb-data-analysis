#!/usr/bin/env Rscript

# Load necessary libraries
suppressPackageStartupMessages({
  library(optparse)
  library(openxlsx)
  library(stringr)
  library(readr)
  library(tools)
})

# -----------------------------------------------------------------------------
# 1. Custom Argument Pre-processing (Handle multiple -i flags)
# -----------------------------------------------------------------------------
raw_args <- commandArgs(trailingOnly = TRUE)
input_folders <- c()
args_for_optparse <- c()
skip_next <- FALSE

for (i in seq_along(raw_args)) {
  if (skip_next) {
    skip_next <- FALSE
    next
  }
  
  arg <- raw_args[i]
  
  if (arg == "-i" || arg == "--input") {
    if (i + 1 <= length(raw_args)) {
      input_folders <- c(input_folders, raw_args[i + 1])
      skip_next <- TRUE
    }
  } else {
    args_for_optparse <- c(args_for_optparse, arg)
  }
}

# -----------------------------------------------------------------------------
# 2. Standard Argument Parsing (for -o and -m)
# -----------------------------------------------------------------------------
option_list <- list(
  make_option(c("-i", "--input"), type = "character", default = NULL, 
              help = "Input directory (can be used multiple times)", metavar = "folder_name"),
  make_option(c("-o", "--output"), type = "character", default = ".", 
              help = "Output directory (default: current)", metavar = "output_folder"),
  make_option(c("-m", "--name-map"), type = "character", default = NULL, 
              help = "Column name mapping CSV file", metavar = "column_name_mapping")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser, args = args_for_optparse)

# -----------------------------------------------------------------------------
# 3. Validation
# -----------------------------------------------------------------------------

if (length(input_folders) == 0) {
  if (!is.null(opt$input)) {
    input_folders <- c(opt$input)
  } else {
    print_help(opt_parser)
    stop("At least one input folder (-i) is required.", call. = FALSE)
  }
}

if (is.null(opt$`name-map`)) {
  print_help(opt_parser)
  stop("Name map file (-m) is required.", call. = FALSE)
}

# Validate inputs
for (d in input_folders) {
  if (!dir.exists(d)) stop(paste("Input directory does not exist:", d))
}
if (!file.exists(opt$`name-map`)) stop("Mapping file does not exist.")
if (!dir.exists(opt$output)) dir.create(opt$output, recursive = TRUE)

# -----------------------------------------------------------------------------
# 4. Helper Functions
# -----------------------------------------------------------------------------

is_ignored_column <- function(x) {
  clean_x <- as.character(x[!is.na(x)])
  if (length(clean_x) == 0) return(TRUE)
  keywords <- c("NA", "TRUE", "FALSE", "GENERAL")
  all(clean_x %in% keywords)
}

is_link_column <- function(x) {
  clean_x <- as.character(x[!is.na(x)])
  if (length(clean_x) == 0) return(FALSE)
  url_pattern <- "^https?://.+"
  all(str_detect(clean_x, url_pattern))
}

# -----------------------------------------------------------------------------
# 5. Main Processing Logic (Loop per Folder)
# -----------------------------------------------------------------------------

map_df <- read_csv(opt$`name-map`, show_col_types = FALSE)

message(paste("Processing", length(input_folders), "input folders..."))

for (folder_path in input_folders) {
  
  folder_name <- basename(folder_path)
  csv_files <- list.files(folder_path, pattern = "\\.csv$", full.names = TRUE)
  
  if (length(csv_files) == 0) {
    warning(paste("No CSV files found in:", folder_path, "- Skipping."))
    next
  }

  message(paste("--> Processing folder:", folder_name, "(", length(csv_files), "files )"))

  # Reset state for this folder
  processed_sheets <- list()
  has_type_flag <- FALSE 
  
  # --- Process Files in this Folder ---
  for (f_path in csv_files) {
    fname <- file_path_sans_ext(basename(f_path))
    
    # Parse filename structure: {SYMBOL}-{TYPE?}-{DATE}-{DATE}
    parts <- str_split(fname, "-")[[1]]
    symbol <- parts[1]
    
    # Logic for determining Type
    is_valid_type <- FALSE
    type_val <- ""
    
    if (length(parts) >= 2) {
      potential_type <- parts[2]
      # Check if potential_type is NOT just digits (treat dates/numbers as NO type)
      if (!str_detect(potential_type, "^\\d+$")) {
        is_valid_type <- TRUE
        type_val <- potential_type
      }
    }
    
    if (is_valid_type) {
      sheet_name <- paste0(symbol, "-", type_val)
      has_type_flag <- TRUE
    } else {
      sheet_name <- symbol
    }
    
    # Read Data
    df <- read_csv(f_path, show_col_types = FALSE, col_types = cols(.default = "c"))
    
    # Data Cleaning
    df <- df[, !names(df) %in% c("id", "isin")]
    
    cols_to_keep <- !sapply(df, is_ignored_column)
    df <- df[, cols_to_keep, drop = FALSE]
    
    cols_to_keep_links <- !sapply(df, is_link_column)
    df <- df[, cols_to_keep_links, drop = FALSE]
    
    processed_sheets[[sheet_name]] <- df
  }
  
  # --- Write Excel for this Folder ---
  wb <- createWorkbook()
  
  for (sheet in names(processed_sheets)) {
    df <- processed_sheets[[sheet]]
    
    addWorksheet(wb, sheet)
    writeData(wb, sheet, df)
    
    # Add Header Comments
    for (i in seq_along(names(df))) {
      col_name <- names(df)[i]
      match_row <- map_df[map_df$`Data Name` == col_name, ]
      
      if (nrow(match_row) > 0) {
        readable <- match_row$`Readable Name`[1]
        notes <- match_row$Notes[1]
        if (is.na(notes)) notes <- ""
        
        comment_text <- paste0(readable, ": ", notes)
        cmt <- createComment(comment = comment_text, visible = FALSE)
        writeComment(wb, sheet, col = i, row = 1, comment = cmt)
      }
    }
  }
  
  # Determine Output Filename
  # Warning: This intentionally allows overwriting if multiple input folders 
  # map to the same output filename (e.g. both generate 'all.xlsx')
  filename <- if (has_type_flag) "all-all.xlsx" else "all.xlsx"
  output_path <- file.path(opt$output, filename)
  
  saveWorkbook(wb, output_path, overwrite = TRUE)
  message(paste("    Saved:", output_path))
}

message("All processing complete.")
