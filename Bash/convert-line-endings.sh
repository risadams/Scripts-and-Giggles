#!/bin/bash

# Ensure dos2unix is installed
if ! command -v dos2unix &>/dev/null; then
  echo "Error: dos2unix is not installed. Install it first (e.g., 'sudo apt install dos2unix')."
  exit 1
fi

# Function to process files recursively
convert_line_endings() {
  local dir="$1"
  for file in "$dir"/*; do
    if [ -d "$file" ]; then
      # If it's a directory, call the function recursively
      convert_line_endings "$file"
    elif [ -f "$file" ]; then
      # If it's a file, convert line endings
      echo "Converting: $file"
      dos2unix "$file" &>/dev/null
    fi
  done
}

# Start conversion from the current directory
convert_line_endings "."

echo "Conversion completed!"
