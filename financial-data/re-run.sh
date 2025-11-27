#!/usr/bin/bash -ue

start_date="2016-01-01"

Rscript ./generator.r AAPL "$start_date" -k ./api-key.txt -f ./results
Rscript ./generator.r GOOG "$start_date" -k ./api-key.txt -f ./results
Rscript ./generator.r MSFT "$start_date" -k ./api-key.txt -f ./results
Rscript ./generator.r META "$start_date" -k ./api-key.txt -f ./results

Rscript ./generator.r TSLA "$start_date" -k ./api-key.txt -f ./results
