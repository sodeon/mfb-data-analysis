#!/usr/bin/bash -ue

start_date="2019-01-01"
# end_date="2025-11-27"

Rscript ./generator.r ../4_raw-data-restructure/results/all.xlsx ../4_raw-data-restructure/results/all-all.xlsx results -s $start_date
