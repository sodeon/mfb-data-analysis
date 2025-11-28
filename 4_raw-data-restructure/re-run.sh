#!/usr/bin/bash -ue

Rscript ./generator.r -i ../2_stock-prices/results -i ../3_financial-data/results -o results -m name-mapping.csv
