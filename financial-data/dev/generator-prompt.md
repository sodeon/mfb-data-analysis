### **R Script Specification: Quarterly Financial Data Downloader**

**1. Core Objective**
A CLI-based R script to download historical quarterly financial statements (Income Statement, Balance Sheet, Cash Flow, and Derived Ratios) for a specific US stock using the `simfinapi` package.

**2. Technical Stack**
* **Language:** R (executed via `Rscript`).
* **Key Packages:** `simfinapi` (v1.0.0+), `optparse`, `lubridate`, `dplyr`, `readr`, `fs`, `stringr`.

**3. CLI Interface**
* **Usage:** `Rscript script.R [OPTIONS] SYMBOL [START_DATE] [END_DATE]`
* **Positional Arguments:**
    1.  `SYMBOL`: Stock Ticker (Required, e.g., "AAPL").
    2.  `START_DATE`: Format YYYY-MM-DD (Optional, defaults to 1 year prior to End Date).
    3.  `END_DATE`: Format YYYY-MM-DD (Optional, defaults to Today).
* **Flags:**
    * `-f`, `--folder`: Target output directory (Defaults to current directory `.` if omitted).
    * `-k`, `--keyfile`: Path to a text file containing the SimFin API key (Optional).

**4. Logic & Behaviors**
* **API Authentication:**
    * If `-k` is provided, read key from file.
    * If `-k` is omitted, prompt user for input (interactive mode) or read from `stdin`.
* **Caching Strategy:**
    * **Linux:** Sets cache to `/tmp/simfin_cache`.
    * **Windows:** Sets cache to `%TEMP%/simfin_cache`.
    * **Other:** Fallback to `tempdir()`.
* **Data Fetching:**
    * Function used: `sfa_load_statements()`.
    * **Strict Period:** Explicitly requests `period = c("q1", "q2", "q3", "q4")` to ensure quarterly granularity.
    * **Date Filtering:** Passes `start` and `end` arguments to the API explicitly cast as `as.Date()` objects.
* **Data Processing:**
    * Fetches 4 Datasets:
        1.  **Profit & Loss (`pl`)** $\rightarrow$ Output Label: **`IS`**
        2.  **Balance Sheet (`bs`)** $\rightarrow$ Output Label: **`BS`**
        3.  **Cash Flow (`cf`)** $\rightarrow$ Output Label: **`CF`**
        4.  **Derived Ratios (`derived`)** $\rightarrow$ Output Label: **`RI`**
    * **Sorting:** Descending order by Report Date (Newest first).
    * **Aggregation:** Consolidates all quarters into a single CSV file per statement type.

**5. Output Specifications**
* **Format:** CSV.
* **Filename Pattern:** `{Symbol}-{Type}-{Start_Date}-to-{End_Date}.csv`
    * *Example:* `AAPL-IS-2020-01-01-to-2023-12-31.csv`
* **Location:** Saves strictly to the folder defined by `-f`, creating the directory if it does not exist.
