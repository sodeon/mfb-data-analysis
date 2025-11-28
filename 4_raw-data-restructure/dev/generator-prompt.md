### **Project Spec: CSV to Excel Merger (R)**

**Overview:**
A CLI tool written in R that merges multiple CSV files from specified input directories into formatted Excel (`.xlsx`) files. It handles data cleaning, intelligent tab naming based on filenames, and adds metadata comments to headers.

**Libraries:** `optparse`, `openxlsx`, `stringr`, `readr`, `tools`

**1. CLI Interface**
* **`-i`, `--input`**: Input directory path. **Repeatable** (e.g., `-i folderA -i folderB`). The script processes each folder independently.
* **`-o`, `--output`**: Output directory path (Defaults to current directory).
* **`-m`, `--name-map`**: Path to a CSV file containing column metadata. Required columns: `Data Name`, `Readable Name`, `Notes`.

**2. Input File Naming & Parsing**
* **Pattern:** `{SYMBOL}-{TYPE}-{DATE}-{DATE}.csv` (hyphen-separated).
* **Type Detection Logic:**
    * Analyze the **2nd segment** of the filename.
    * If segment contains **only digits** (e.g., `2023`, `1`) $\rightarrow$ Treat as **No Type** (Date/Number).
    * If segment contains **text** (e.g., `BS`, `Income`) $\rightarrow$ Treat as **Valid Type**.

**3. Output Logic (Per Input Folder)**
* **Scope:** The script loops through each `-i` folder and generates one distinct Excel file for that folder.
* **Tab Naming:**
    * **With Type:** Tab name = `{SYMBOL}-{TYPE}`.
    * **No Type:** Tab name = `{SYMBOL}`.
* **Filename Generation:**
    * If *any* file in the folder has a Valid Type $\rightarrow$ Output file is **`all-all.xlsx`**.
    * If *no* files have a Valid Type $\rightarrow$ Output file is **`all.xlsx`**.
    * **Collision Rule:** If multiple input folders result in the same output filename, the file in the output directory is **overwritten** (no folder prefix in filename).

**4. Data Processing & Cleaning**
* **Column Removal:**
    1.  Columns named `id` or `isin`.
    2.  Columns where **all** non-NA values are: `"NA"`, `"TRUE"`, `"FALSE"`, or `"GENERAL"`.
    3.  Columns where **all** non-NA values match URL regex (`^https?://.+`).

**5. Excel Formatting**
* **Header Comments:**
    * Match column names against `Data Name` in the map file.
    * Insert an Excel comment on the header cell (Row 1).
    * **Format:** `"{Readable Name}: {Notes}"`.

***

**Would you like me to generate a `README.md` file containing these specs and the usage examples?**
