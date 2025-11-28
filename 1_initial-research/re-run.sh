#!/usr/bin/bash -ue
shopt -s expand_aliases
which Rscript || alias Rscript="Rscript.exe"

export GOOGLE_API_KEY="AIzaSyBCX8vFG6CKYchSo8ByvUZq8ZJC0FR-sNM"
export WSLENV=GOOGLE_API_KEY
symbol="GOOG"
model="gemini-3-pro-preview"

Rscript ../src/template-ai-chat.r prompt.txt ./results -r {SYMBOL}="$symbol" -m $model
