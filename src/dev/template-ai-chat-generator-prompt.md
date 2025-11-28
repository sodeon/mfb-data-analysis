### **Project Specification: R CLI AI Batch Processor**

**Description:**
A command-line interface (CLI) tool written in R that reads a batch of prompts from a text file, processes them using the `ellmer` package (Google Gemini models), and handles file outputs (CSV/Markdown) via function calling.

**Tech Stack:**

  * **Language:** R
  * **Key Libraries:** `ellmer` (\>=0.4.0), `docopt`, `readr`, `stringr`, `fs`.
  * **AI Provider:** Google Gemini (default: `gemini-2.5-pro`, configurable).

-----

### **1. CLI Interface (`docopt`)**

**Usage:**

```bash
Rscript ai_runner.R <input_file> [<output_folder>] [-r <replace>]... [-m <ai_model>] [-d]
```

**Arguments:**

  * **Positional:**
      * `input_file`: Path to the text file containing prompts.
      * `output_folder`: (Optional) Directory to save AI-generated files. Defaults to current working directory (`getwd()`).
  * **Options:**
      * `-r, --replace <replace>`: Token replacement in format `{TOKEN}=VALUE`. Can be used multiple times.
      * `-m, --model <ai_model>`: Specify the Gemini model to use (e.g., `gemini-1.5-flash`). **Default:** `gemini-2.5-pro`.
      * `-d, --dry-run`: Preview processed prompts and replacements without calling the API or creating files.

-----

### **2. Input Specifications**

  * **Prompt File:**
      * Questions are delimited by lines starting with `Q:`.
      * Everything between one `Q:` and the next (or EOF) is treated as a single prompt block.
      * **Logic:** The script explicitly removes the `Q:` prefix and leading whitespace from the prompt before sending it to the AI.
  * **Token Replacement:**
      * Literal string replacement is performed on the prompt text using values provided via `-r`.
      * Example: `{SYMBOL}=AAPL` replaces all instances of `{SYMBOL}` with `AAPL`.

-----

### **3. Authentication**

  * **Method:** Environment Variable.
  * **Requirement:** The script expects `GOOGLE_API_KEY` to be set in the system environment.
  * **Validation:** The script stops execution if `Sys.getenv("GOOGLE_API_KEY")` is empty (unless in Dry Run mode).

-----

### **4. AI Logic & Tooling (Ellmer Implementation)**

  * **Tool Definition:**
      * **Name:** `save_file_tool`
      * **Function:** Writes content to disk (`readr::write_file`).
      * **Schema:** Defined using `ellmer::tool()` with an `arguments` list (filename string, content string).
  * **Tool Registration:**
      * Tools are registered using `chat$register_tool(tool_def)` immediately after chat initialization.
  * **System Prompt:**
      * Strictly instructs the AI to use `save_file_tool` for any CSV or Markdown output requests.
  * **Session Management (Crucial):**
      * The `chat_google_gemini` object is **re-initialized** inside the processing loop for *every* prompt.
      * **Reason:** To ensure a clean context window and prevent "HTTP 400 Bad Request" errors caused by history contamination between distinct batch tasks.

### **5. Execution Flow**

1.  **Parse:** Read input file and split into prompt blocks.
2.  **Dry Run Check:** If `-d` is set, print parsed/replaced text and exit.
3.  **Loop:** Iterate through prompts.
      * Apply replacements.
      * Initialize new AI Chat session.
      * Register Tool.
      * Send message (`chat$chat`).
      * Print response to console (Tools execute automatically to save files).
      * Handle errors (try-catch block) to ensure one failed prompt doesn't crash the batch.
