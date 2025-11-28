#!/usr/bin/bash -ue
shopt -s expand_aliases
which Rscript || alias Rscript="Rscript.exe"

start_date="2016-01-01"
end_date="2025-11-27"


Rscript ./generator.r AAPL "$start_date" "$end_date" -f ./results
Rscript ./generator.r GOOG "$start_date" "$end_date" -f ./results
Rscript ./generator.r MSFT "$start_date" "$end_date" -f ./results
Rscript ./generator.r META "$start_date" "$end_date" -f ./results
Rscript ./generator.r AMZN "$start_date" "$end_date" -f ./results

Rscript ./generator.r TSLA "$start_date" "$end_date" -f ./results
