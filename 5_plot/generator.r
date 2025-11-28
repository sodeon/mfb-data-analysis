#!/usr/bin/env Rscript

# Load necessary libraries
suppressPackageStartupMessages({
  library(optparse)
  library(readxl)
  library(openxlsx)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(ggplot2)
  if (!requireNamespace("xml2", quietly = TRUE)) {
    warning("Package 'xml2' is not installed. Comments will not be preserved.")
  } else {
    library(xml2)
  }
})

# --- 1. Argument Parsing ---

option_list <- list(
  make_option(c("-s", "--start"), type = "character", default = NULL,
              help = "Start date (yyyy/mm/dd or yyyy-mm-dd)", metavar = "DATE"),
  make_option(c("-e", "--end"), type = "character", default = NULL,
              help = "End date (yyyy/mm/dd or yyyy-mm-dd)", metavar = "DATE")
)

parser <- OptionParser(usage = "%prog [options] input_file1 [input_file2 ...] [output_folder]", option_list = option_list)
arguments <- parse_args(parser, positional_arguments = TRUE)

opt <- arguments$options
args <- arguments$args

if (length(args) < 1) {
  print_help(parser)
  stop("Error: No input files provided.", call. = FALSE)
}

# --- Determine Inputs and Output ---

potential_output <- args[length(args)]
input_files <- character()
output_folder <- "."

if (length(args) == 1) {
  input_files <- args
  output_folder <- "."
} else {
  if (file.exists(potential_output) && !dir.exists(potential_output)) {
    input_files <- args
    output_folder <- "."
  } else {
    input_files <- args[1:(length(args)-1)]
    output_folder <- potential_output
  }
}

if (!dir.exists(output_folder)) {
  dir.create(output_folder, recursive = TRUE)
  cat(sprintf("Created output directory: %s\n", output_folder))
}

# --- Load Plot Functions ---

script_dir <- dirname(sub("--file=", "", commandArgs(trailingOnly = FALSE)[4]))
if (length(script_dir) == 0 || script_dir == ".") script_dir <- getwd()

plot_script_path <- file.path(script_dir, "plot.r")
if (!file.exists(plot_script_path)) plot_script_path <- "plot.r"

if (file.exists(plot_script_path)) {
  source(plot_script_path)
} else {
  stop("Error: plot.r not found.", call. = FALSE)
}

if (!exists("PLOT_FUNCTIONS") || !is.list(PLOT_FUNCTIONS)) {
  stop("Error: plot.r must define 'PLOT_FUNCTIONS'.", call. = FALSE)
}

# --- 2. Comment Extraction Helpers ---

excel_col_to_int <- function(col_str) {
  chars <- strsplit(col_str, "")[[1]]
  vals <- match(chars, LETTERS)
  sum(vals * 26^((length(vals)-1):0))
}

parse_cell_ref <- function(ref) {
  match <- regexec("^([A-Z]+)([0-9]+)$", ref)
  parts <- regmatches(ref, match)[[1]]
  if (length(parts) < 3) return(NULL)
  list(
    col = excel_col_to_int(parts[2]),
    row = as.integer(parts[3])
  )
}

extract_xlsx_comments <- function(xlsx_file) {
  if (!requireNamespace("xml2", quietly = TRUE)) return(list())
  
  temp_dir <- tempfile()
  dir.create(temp_dir)
  utils::unzip(xlsx_file, exdir = temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  # 1. Map Sheet Name -> rId
  wb_xml_path <- file.path(temp_dir, "xl", "workbook.xml")
  if (!file.exists(wb_xml_path)) return(list())
  
  wb_doc <- read_xml(wb_xml_path)
  sheets <- xml_find_all(wb_doc, ".//*[local-name()='sheet']")
  
  sheet_map <- list()
  for (node in sheets) {
    name <- xml_attr(node, "name")
    rid <- xml_attr(node, "id")
    if (is.na(rid)) rid <- xml_attr(node, "r:id")
    if (is.na(rid)) {
      attrs <- xml_attrs(node)
      rid <- attrs[grep("id", names(attrs), ignore.case = TRUE)][1]
    }
    sheet_map[[name]] <- rid
  }
  
  # 2. Map rId -> Sheet File
  rels_path <- file.path(temp_dir, "xl", "_rels", "workbook.xml.rels")
  if (!file.exists(rels_path)) return(list())
  
  rels_doc <- read_xml(rels_path)
  rels <- xml_find_all(rels_doc, ".//*[local-name()='Relationship']")
  
  rid_file_map <- list()
  for (node in rels) {
    id <- xml_attr(node, "Id")
    target <- xml_attr(node, "Target")
    rid_file_map[[id]] <- target
  }
  
  all_sheet_comments <- list()
  
  for (sheet_name in names(sheet_map)) {
    rid <- sheet_map[[sheet_name]]
    sheet_file_rel <- rid_file_map[[rid]]
    
    if (is.null(sheet_file_rel)) next
    
    full_sheet_path <- file.path(temp_dir, "xl", sheet_file_rel)
    
    # 3. Find Comments File
    sheet_filename <- basename(full_sheet_path)
    sheet_rels_path <- file.path(temp_dir, "xl", "worksheets", "_rels", paste0(sheet_filename, ".rels"))
    
    if (!file.exists(sheet_rels_path)) next
    
    sheet_rels_doc <- read_xml(sheet_rels_path)
    comment_rel <- xml_find_first(sheet_rels_doc, ".//*[local-name()='Relationship'][contains(@Type, 'comments')]")
    
    if (inherits(comment_rel, "xml_missing")) next
    
    comment_target <- xml_attr(comment_rel, "Target")
    comment_file_path <- file.path(temp_dir, "xl", "worksheets", comment_target)
    comment_file_path <- normalizePath(comment_file_path, mustWork = FALSE)
    
    if (!file.exists(comment_file_path)) next
    
    # 4. Parse Comments
    comments_doc <- read_xml(comment_file_path)
    comment_nodes <- xml_find_all(comments_doc, ".//*[local-name()='comment']")
    
    parsed_comments <- list()
    for (cnode in comment_nodes) {
      ref <- xml_attr(cnode, "ref")
      text_nodes <- xml_find_all(cnode, ".//*[local-name()='t']")
      text_content <- paste(xml_text(text_nodes), collapse = "")
      
      coords <- parse_cell_ref(ref)
      if (!is.null(coords)) {
        parsed_comments[[length(parsed_comments) + 1]] <- list(
          row = coords$row,
          col = coords$col,
          text = text_content,
          author = "System"
        )
      }
    }
    all_sheet_comments[[sheet_name]] <- parsed_comments
  }
  
  return(all_sheet_comments)
}

# --- 3. Other Helper Functions ---

find_date_col <- function(col_names) {
  if ("date" %in% col_names) return("date")
  if ("report_date" %in% col_names) return("report_date")
  if ("publish_date" %in% col_names) return("publish_date")
  return(NULL)
}

parse_sheet_name <- function(sheet_name) {
  parts <- str_split(sheet_name, "-")[[1]]
  symbol <- parts[1]
  type <- if (length(parts) > 1) paste(parts[-1], collapse = "-") else "Price"
  list(symbol = symbol, type = type, sheet = sheet_name)
}

# --- 4. Global Processing Loop ---

global_plots_by_symbol <- list() 
global_raw_data_sheets <- list()

cat(sprintf("Output will be consolidated to: all.xlsx\n"))

for (current_input_file in input_files) {
  cat(sprintf("========================================\n"))
  cat(sprintf("Processing File: %s\n", current_input_file))
  
  if (!file.exists(current_input_file)) {
    cat(sprintf("Error: File not found: %s\n", current_input_file))
    next
  }

  cat("  Extracting comments...\n")
  file_comments <- tryCatch(extract_xlsx_comments(current_input_file), error = function(e) list())

  sheet_names <- excel_sheets(current_input_file)
  
  for (sheet_name in sheet_names) {
    cat(sprintf("  Reading sheet: %s\n", sheet_name))
    
    df <- suppressWarnings(read_excel(current_input_file, sheet = sheet_name))
    
    # FIX: Use a standard identifier for the row tracker
    if (nrow(df) > 0) {
      df$orig_row_index <- 2:(nrow(df) + 1)
    } else {
      df$orig_row_index <- integer(0)
    }
    
    # Filter Date
    date_col <- find_date_col(colnames(df))
    if (!is.null(date_col)) {
      df[[date_col]] <- tryCatch(
        as.Date(df[[date_col]]), 
        error = function(e) as.Date(parse_date_time(df[[date_col]], orders = c("ymd", "mdy", "dmy")))
      )
      
      start_date <- if (!is.null(opt$start)) ymd(opt$start) else min(df[[date_col]], na.rm = TRUE)
      end_date <- if (!is.null(opt$end)) ymd(opt$end) else max(df[[date_col]], na.rm = TRUE)
      
      df <- df %>% filter(.data[[date_col]] >= start_date, .data[[date_col]] <= end_date)
    }
    
    # Map Comments to New Data
    raw_comments <- file_comments[[sheet_name]]
    kept_comments <- list()
    
    if (!is.null(raw_comments)) {
      for (c in raw_comments) {
        if (c$row == 1) {
          # Header comment
          kept_comments[[length(kept_comments) + 1]] <- c
        } else {
          # FIX: Use matched valid identifier
          match_idx <- which(df$orig_row_index == c$row)
          if (length(match_idx) > 0) {
            new_c <- c
            new_c$row <- match_idx + 1
            kept_comments[[length(kept_comments) + 1]] <- new_c
          }
        }
      }
    }
    
    # FIX: Remove the valid identifier column
    df$orig_row_index <- NULL
    
    # Store raw data and comments
    global_raw_data_sheets[[length(global_raw_data_sheets) + 1]] <- list(
      name = sheet_name, 
      data = df, 
      comments = kept_comments
    )
    
    # Generate Plots
    meta <- parse_sheet_name(sheet_name)
    symbol <- meta$symbol
    
    if (is.null(global_plots_by_symbol[[symbol]])) {
      global_plots_by_symbol[[symbol]] <- list()
    }
    
    for (plot_func_name in names(PLOT_FUNCTIONS)) {
      plot_func <- PLOT_FUNCTIONS[[plot_func_name]]
      p <- tryCatch({
        plot_func(df, meta)
      }, error = function(e) NULL)
      
      if (!is.null(p) && inherits(p, "ggplot")) {
        idx <- length(global_plots_by_symbol[[symbol]]) + 1
        global_plots_by_symbol[[symbol]][[idx]] <- p
      }
    }
  }
}

# --- 5. Writing Phase ---

wb <- createWorkbook()
temp_image_files <- character()

cat(sprintf("========================================\n"))
cat("Generating Consolidated Output...\n")

# GROUP 1: Plot Tabs
cat("  Generating Plot Tabs...\n")
sorted_symbols <- sort(names(global_plots_by_symbol))

for (symbol in sorted_symbols) {
  symbol_plots <- global_plots_by_symbol[[symbol]]
  
  if (length(symbol_plots) > 0) {
    plot_sheet_name <- paste0(symbol, "_Plots")
    if (nchar(plot_sheet_name) > 31) plot_sheet_name <- substr(plot_sheet_name, 1, 31)
    
    addWorksheet(wb, plot_sheet_name)
    
    current_row <- 1
    plot_width <- 10 
    plot_height <- 6 
    rows_per_plot <- 35 
    
    for (p in symbol_plots) {
      tmp_plot_file <- tempfile(fileext = ".png")
      temp_image_files <- c(temp_image_files, tmp_plot_file)
      
      tryCatch({
        ggsave(filename = tmp_plot_file, plot = p, 
               width = plot_width, height = plot_height, units = "in", dpi = 300)
        
        insertImage(wb, sheet = plot_sheet_name, file = tmp_plot_file, 
                    startRow = current_row, width = plot_width, height = plot_height, units = "in")
      }, error = function(e) {
        cat(sprintf("    Error saving plot for %s: %s\n", symbol, e$message))
      })
      
      current_row <- current_row + rows_per_plot
    }
  }
}

# GROUP 2: Raw Data Tabs with Comments
cat("  Generating Raw Data Tabs...\n")
for (item in global_raw_data_sheets) {
  sheet_name <- item$name
  df <- item$data
  comments <- item$comments
  
  safe_name <- sheet_name
  counter <- 1
  while (safe_name %in% names(wb)) {
    base_len <- 31 - (nchar(as.character(counter)) + 1)
    safe_name <- paste0(substr(sheet_name, 1, base_len), "_", counter)
    counter <- counter + 1
  }
  
  addWorksheet(wb, safe_name)
  writeData(wb, sheet = safe_name, x = df)
  
  if (length(comments) > 0) {
    for (c in comments) {
      c_obj <- createComment(comment = c$text, author = c$author)
      writeComment(wb, sheet = safe_name, col = c$col, row = c$row, comment = c_obj)
    }
  }
}

# --- 6. Save File ---

output_filename <- "all.xlsx"
output_path <- file.path(output_folder, output_filename)

cat(sprintf("Saving consolidated output to: %s\n", output_path))
saveWorkbook(wb, output_path, overwrite = TRUE)

if (length(temp_image_files) > 0) {
  unlink(temp_image_files)
}

cat("Done.\n")
