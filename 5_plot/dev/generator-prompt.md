### Project: Financial Data Plotting CLI (R)

**Files:** `main.R` (Orchestrator), `plot.r` (Plot definitions)
**Language:** R
**Dependencies:** `optparse`, `readxl`, `openxlsx`, `dplyr`, `stringr`, `lubridate`, `ggplot2`, `scales`, `xml2`

#### 1. CLI Interface & Inputs
* **Positional Arguments:**
    * Accepts **multiple input files** (Excel `.xlsx`).
    * **Last Argument Logic:**
        * If the last argument is an existing *file*, it is treated as an input file, and output defaults to current directory (`.`).
        * Otherwise, the last argument is treated as the **output folder**.
* **Optional Flags:**
    * `-s`, `--start`: Start date (format: yyyy-mm-dd or yyyy/mm/dd).
    * `-e`, `--end`: End date (format: yyyy-mm-dd or yyyy/mm/dd).

#### 2. Data Processing Logic
* **Sheet Parsing:** Reads all sheets from all input files.
* **Metadata Extraction:** Parses sheet names via `{SYMBOL}` or `{SYMBOL}-{TYPE}` convention (default Type = "Price").
* **Date Filtering:**
    * Column precedence: `date` > `report_date` > `publish_date`.
    * Filters rows based on the provided start/end flags.
* **Comment Preservation:**
    * Uses `xml2` to parse the underlying XML of the `.xlsx` input.
    * Extracts comments and maps them to the correct rows in the filtered dataset (tracking original row indices vs. filtered indices).
* **Consolidation:** Aggregates data and plots from *all* input files into memory before writing.

#### 3. Plotting System (`plot.r`)
* **Registry:** Defines a `PLOT_FUNCTIONS` list containing:
    1.  `price_history` (Type: Price) - Line/Area chart of Close price.
    2.  `income_statement` (Type: IS) - Revenue vs. Net Income.
    3.  `balance_sheet` (Type: BS) - Assets (Bar) vs. Liabilities (Line).
* **Standards:**
    * **Input:** Dataframe + Metadata list (`symbol`, `type`).
    * **Output:** `ggplot2` object or `NULL`.
    * **Formatting:**
        * Uses `linewidth` (not `size`) and tidy evaluation (`.data[[]]`) for compatibility with modern `ggplot2`.
        * **Y-Axis:** Uses `scales::cut_short_scale()` to abbreviate large numbers (K, M, B, T) and auto-detects currency symbols from the data column `currency`.
        * **Data Safety:** Explicitly forces relevant columns to `numeric` to prevent "discrete value" errors.

#### 4. Output Specification
* **File Name:** Fixed as `all.xlsx` inside the specified output folder.
* **Structure & Ordering:**
    1.  **Plot Tabs (First):**
        * One tab per **Symbol** (e.g., `AAPL_Plots`).
        * All plots for that symbol are vertically stacked (saved as temp PNGs via `ggsave` and inserted via `insertImage`).
    2.  **Raw Data Tabs (Second):**
        * Contains the filtered raw data.
        * Naming: Original sheet name (with unique numeric suffixing if collisions occur).
        * **Comments:** Excel comments are re-inserted into the correct cells using `writeComment`.

***
