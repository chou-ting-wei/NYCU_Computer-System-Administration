#!/bin/bash

URL="http://10.113.0.253/tasks"
JSON_DATA='{"type": "JOIN_NYCU_CSIT"}'
OUTPUT_FILE="hw2-2.txt"

for i in {1..100}; do
  response=$(curl -s -X POST "$URL" \
       -H "Content-Type: application/json" \
       -d "$JSON_DATA")
  
  problem=$(echo "$response" | awk -F'"problem":"' '{print $2}' | awk -F'","' '{print $1}')

  if ! awk -F'"problem":"' '{print $2}' "$OUTPUT_FILE" | awk -F'","' '{print $1}' | grep -q "$problem"; then
    echo "Response #$i:" >> "$OUTPUT_FILE"
    echo "$response" >> "$OUTPUT_FILE"
  else
    echo "Duplicate problem for iteration #$i, skipping..."
  fi

  sleep 0.2
done
