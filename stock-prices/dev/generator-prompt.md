### R Script Specification: Historical Stock Data Downloader

**Objective:**
Create an R CLI script to fetch adjusted historical stock data from Yahoo Finance and export it to CSV with flexible output handling.

**Technical Requirements:**
* **Language:** R
* **Libraries:** `quantmod`, `dplyr`, `tools`
* **Execution:** Command Line Interface (CLI) using `Rscript`.

**Input Parameters (CLI Arguments):**
1.  **Positional Arguments:**
    * `ARG 1` (Required): **Stock Symbol** (e.g., AAPL).
    * `ARG 2` (Optional): **Start Date** (Format: `yyyy-mm-dd` or `yyyy/mm/dd`).
    * `ARG 3` (Optional): **End Date** (Format: `yyyy-mm-dd` or `yyyy/mm/dd`).
2.  **Flags:**
    * `-f {PATH}` (Optional): Specifies the output location or filename.

**Logic & Default Behaviors:**
* **Date Logic:**
    * If `End Date` is missing $\rightarrow$ Default to **Today**.
    * If `Start Date` is missing $\rightarrow$ Default to **exactly 1 year prior** to End Date.
* **Path Logic (`-f` flag):**
    * If `-f` is **omitted** $\rightarrow$ Save to current directory using the Default Filename.
    * If `-f` is an **existing folder** $\rightarrow$ Save to that folder using the Default Filename.
    * If `-f` is a **file path/name** $\rightarrow$ Save exactly to that path/filename (creating parent directories if needed).

**Data Processing:**
* **Source:** Yahoo Finance (`getSymbols`).
* **Adjustment:** Apply `adjustOHLC(..., use.Adjusted = TRUE)` to ensure Open, High, and Low prices are adjusted for splits and dividends, consistent with the Adjusted Close.
* **Formatting:**
    * Round all price columns to **2 decimal places**.
    * Ensure strict Date format (`YYYY-MM-DD`) in the output.

**Output Specifications:**
* **File Format:** CSV.
* **Default Filename Pattern:** `{Symbol}-{Start_Date}-to-{End_Date}.csv`
    * *Example:* `AAPL-2023-01-01-to-2024-01-01.csv`
* **CSV Columns (Ordered):**
    1.  `date`
    2.  `open`
    3.  `close`
    4.  `high`
    5.  `low`
    6.  `volume`
