#!/usr/bin/bash -ue

symbol="AAPL"
GOOGLE_API_KEY=AIzaSyDGAoirUab5Ch7cedbmTTqDJOCmOiBR6YU 
model="gemini-3-pro"

GOOGLE_API_KEY="$GOOGLE_API_KEY" Rscript ../src/template-ai-chat.r prompt.txt ./results -r {SYMBOL}="$symbol" -m $model
