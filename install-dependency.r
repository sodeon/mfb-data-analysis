#!/usr/bin/env Rscript

# Stock prices
install.packages(c("quantmod", "dplyr", "tools"))

# Financial data
install.packages(c("optparse", "simfinapi", "lubridate", "dplyr", "readr", "fs"))

# AI chat
install.packages(c("ellmer", "docopt", "readr", "stringr", "fs"))

# Raw data restructure
install.packages(c("optparse", "openxlsx", "stringr", "readr"))

# Plot
install.packages(c("readxl", "openxlsx", "stringr", "ggplot2"))



#--------------------------------------------------
# For Ubuntu/Debian Linux
#--------------------------------------------------
# sudo apt install libcurl4-openssl-dev # for quantmod
# sudo apt install npm
