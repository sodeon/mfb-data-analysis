#!/usr/bin/bash -ue

symbol="AAPL"
google_api_key=AIzaSyDGAoirUab5Ch7cedbmTTqDJOCmOiBR6YU 
model="gemini-3-pro-preview"

GOOGLE_API_KEY="$google_api_key" Rscript ../src/template-ai-chat.r prompt.txt ./results -r {SYMBOL}="$symbol" -m $model
