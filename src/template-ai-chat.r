#!/usr/bin/env Rscript

# 1. Load required libraries
suppressMessages({
  library(docopt)
  library(ellmer)
  library(readr)
  library(stringr)
  library(fs)
})

# 2. Define CLI Interface
doc <- "
AI Batch Processor

Usage:
  ai_runner.R <input_file> [<output_folder>] [-r <replace>]... [-m <ai_model>] [-d]
  ai_runner.R (-h | --help)

Options:
  -h --help                         Show this screen.
  -r, --replace <replace>           Replace token in prompt (format: {TOKEN}=VALUE). 
  -m, --model <ai_model>            Specify the AI model (default: gemini-2.5-pro).
  -d, --dry-run                     Process prompts and show replacements without calling the AI.
  <output_folder>                   Output directory (defaults to current folder).
"

# Parse arguments
args <- docopt(doc)

# 3. Setup Configuration
input_file <- args$input_file
output_dir <- if (is.null(args$output_folder)) getwd() else args$output_folder
replacements <- args$replace
is_dry_run <- args$dry_run
model_name <- if (!is.null(args$model)) args$model else "gemini-2.5-pro"

# 4. Check Environment Variable
if (!is_dry_run) {
  if (Sys.getenv("GOOGLE_API_KEY") == "") {
    stop("Error: GOOGLE_API_KEY environment variable is not set.\nPlease run: export GOOGLE_API_KEY='your_key'")
  }
}

# Ensure output directory exists
if (!dir_exists(output_dir)) {
  dir_create(output_dir)
  if (is_dry_run) cat("(Dry Run) ")
  cat(sprintf("Created output directory: %s\n", output_dir))
}

# 5. Helper Functions
parse_prompts <- function(filepath) {
  if (!file_exists(filepath)) stop("Input file does not exist.")
  lines <- read_lines(filepath)
  starts <- which(str_detect(lines, "^Q:"))
  if (length(starts) == 0) return(list())
  prompts <- list()
  for (i in seq_along(starts)) {
    start_idx <- starts[i]
    end_idx <- if (i < length(starts)) starts[i+1] - 1 else length(lines)
    block <- lines[start_idx:end_idx]
    # Remove "Q:" marker from the first line
    block[1] <- str_remove(block[1], "^Q:\\s*")
    prompts[[i]] <- paste(block, collapse = "\n")
  }
  return(prompts)
}

apply_replacements <- function(text, replace_args) {
  if (length(replace_args) == 0) return(text)
  res <- text
  for (r in replace_args) {
    parts <- str_split(r, "=", n = 2)[[1]]
    if (length(parts) == 2) {
      token <- parts[1]
      value <- parts[2]
      res <- str_replace_all(res, fixed(token), value)
    }
  }
  return(res)
}

# --- DEFINE TOOLS (Do this once) ---
if (!is_dry_run) {
  save_file_func <- function(filename, content) {
    full_path <- path(output_dir, filename)
    write_file(content, full_path)
    return(paste("File saved successfully to:", full_path))
  }

  my_tool_def <- tool(
    save_file_func,
    "Saves data or text to a local file. Use this whenever the user asks for a CSV or Markdown file.",
    name = "save_file_tool",
    arguments = list(
      filename = type_string("The full filename including extension (e.g., 'output.csv', 'report.md')"),
      content = type_string("The complete text or CSV content to be written to the file")
    )
  )
}

# 6. Main Execution Loop
prompts <- parse_prompts(input_file)
cat(sprintf("Found %d prompt(s) in %s. Model: %s\n", length(prompts), input_file, model_name))

for (i in seq_along(prompts)) {
  raw_prompt <- prompts[[i]]
  processed_prompt <- apply_replacements(raw_prompt, replacements)
  
  if (is_dry_run) {
    cat(sprintf("\n[DRY RUN] Prompt %d Preview:\n", i))
    cat("--------------------------------------------------\n")
    cat(processed_prompt)
    cat("\n--------------------------------------------------\n")
  } else {
    cat(sprintf("\n--- Processing Question %d ---\n", i))
    
    # --- CRITICAL FIX: Initialize NEW chat session for every prompt ---
    # This prevents history contamination that causes 400 Bad Request
    tryCatch({
      
      # 1. Create fresh chat instance
      chat <- chat_google_gemini(
        model = model_name,
        system_prompt = paste(
          "You are an intelligent data assistant.",
          "When asked to generate files (CSV, MD, etc.), you MUST use the 'save_file_tool'.",
          "Do not simply print the content in the chat window if a file is requested.",
          "You can call the tool multiple times to save multiple files."
        )
      )
      
      # 2. Register tool to this instance
      chat$register_tool(my_tool_def)
      
      # 3. Send prompt
      response <- chat$chat(processed_prompt)
      
      cat("AI Response:\n")
      print(response)
      cat("\n")
      
    }, error = function(e) {
      cat("Error processing prompt:", e$message, "\n")
    })
  }
}

if (is_dry_run) {
  cat("\nDry run complete. No files were sent to AI or written to disk.\n")
} else {
  cat("\nBatch processing complete.\n")
}
