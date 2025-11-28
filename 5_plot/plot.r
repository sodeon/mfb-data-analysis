library(ggplot2)
library(scales)

# --- Helper Functions ---

# Determine currency symbol from data context
get_currency_symbol <- function(data) {
  if ("currency" %in% colnames(data)) {
    # Get the first non-NA currency value
    curr <- as.character(na.omit(data$currency)[1])
    
    if (is.na(curr) || length(curr) == 0) return("")
    if (curr == "USD") return("$")
    if (curr == "EUR") return("€")
    if (curr == "GBP") return("£")
    if (curr == "JPY") return("¥")
    if (curr == "CNY") return("¥")
    # Fallback: return the code itself with a space (e.g., "AUD ")
    return(paste0(curr, " "))
  }
  return("") # Default to no prefix if unknown
}

# --- Plot Functions ---

# Plot 1: Standard Price Plot (Open/Close)
plot_price_history <- function(data, meta) {
  # Check applicability
  if (meta$type != "Price") return(NULL)
  if (!all(c("date", "close") %in% colnames(data))) return(NULL)
  
  # FIX: Force 'close' to be numeric to avoid "Discrete value" errors
  data$close <- suppressWarnings(as.numeric(data$close))
  
  # Remove rows where conversion failed (NA)
  data <- data[!is.na(data$close), ]
  if (nrow(data) == 0) return(NULL)
  
  curr_sym <- get_currency_symbol(data)
  
  p <- ggplot(data, aes(x = date, y = close)) +
    geom_line(color = "blue", linewidth = 1) +
    geom_area(fill = "lightblue", alpha = 0.3) +
    labs(title = paste(meta$symbol, "- Price History"),
         subtitle = "Close Price over Time",
         x = "Date", y = "Price") +
    scale_y_continuous(n.breaks = 10, 
                       labels = scales::label_dollar(prefix = curr_sym, scale_cut = scales::cut_short_scale())) +
    theme_minimal()
  
  return(p)
}

# Plot 2: Income Statement Revenue vs Net Income
plot_income_statement <- function(data, meta) {
  if (meta$type != "IS") return(NULL)
  
  date_col <- if ("date" %in% colnames(data)) "date" else if ("report_date" %in% colnames(data)) "report_date" else "publish_date"
  
  if (!all(c("revenue", "net_income") %in% colnames(data))) return(NULL)
  
  # FIX: Force columns to numeric
  data$revenue <- suppressWarnings(as.numeric(data$revenue))
  data$net_income <- suppressWarnings(as.numeric(data$net_income))
  
  # Filter out rows where essential data is missing
  data <- data[!is.na(data$revenue) & !is.na(data$net_income), ]
  if (nrow(data) == 0) return(NULL)
  
  curr_sym <- get_currency_symbol(data)
  
  p <- ggplot(data, aes(x = .data[[date_col]])) +
    geom_line(aes(y = revenue, color = "Revenue"), linewidth = 1.2) +
    geom_line(aes(y = net_income, color = "Net Income"), linewidth = 1.2) +
    labs(title = paste(meta$symbol, "- Income Statement"),
         x = "Date", y = "Amount", color = "Metric") +
    scale_y_continuous(n.breaks = 10, 
                       labels = scales::label_dollar(prefix = curr_sym, scale_cut = scales::cut_short_scale())) +
    theme_minimal()
  
  return(p)
}

# Plot 3: Balance Sheet Assets vs Liabilities
plot_balance_sheet <- function(data, meta) {
  if (meta$type != "BS") return(NULL)
  
  date_col <- if ("report_date" %in% colnames(data)) "report_date" else "publish_date"
  
  if (!all(c("total_assets", "total_liabilities") %in% colnames(data))) return(NULL)
  
  # FIX: Force columns to numeric
  data$total_assets <- suppressWarnings(as.numeric(data$total_assets))
  data$total_liabilities <- suppressWarnings(as.numeric(data$total_liabilities))
  
  data <- data[!is.na(data$total_assets) & !is.na(data$total_liabilities), ]
  if (nrow(data) == 0) return(NULL)
  
  curr_sym <- get_currency_symbol(data)

  p <- ggplot(data, aes(x = .data[[date_col]])) +
    geom_bar(aes(y = total_assets, fill = "Total Assets"), stat = "identity", alpha = 0.6) +
    geom_line(aes(y = total_liabilities, group=1, color = "Total Liabilities"), linewidth = 1.5) +
    scale_fill_manual(values = c("Total Assets" = "forestgreen")) +
    scale_color_manual(values = c("Total Liabilities" = "red")) +
    labs(title = paste(meta$symbol, "- Balance Sheet Health"),
         x = "Date", y = "Amount") +
    scale_y_continuous(n.breaks = 10, 
                       labels = scales::label_dollar(prefix = curr_sym, scale_cut = scales::cut_short_scale())) +
    theme_minimal()
    
  return(p)
}

# --- Registry ---
PLOT_FUNCTIONS <- list(
  price_history = plot_price_history,
  income_statement = plot_income_statement,
  balance_sheet = plot_balance_sheet
)
