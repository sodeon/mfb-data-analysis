#!/usr/bin/bash -ue
shopt -s expand_aliases
which Rscript || alias Rscript="Rscript.exe"

Rscript ./generator.r -i ../2_stock-prices/results -i ../3_financial-data/results -o results -m name-mapping.csv
