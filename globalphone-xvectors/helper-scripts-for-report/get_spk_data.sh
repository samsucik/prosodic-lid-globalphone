#!/bin/bash -u

# Copyright 2019 Sam Sucik
# 
# Apache 2.0

# Extracts the dialect and sex of each speaker (where available) directly from the GlobalPhone corpus.
# For each language, creates a CSV file with speaker ID, dialect and sex as columns.
# 
# Usage: Run from the directory in which GlobalPhone resides like this:
# ./get_spk_data.sh directory-for-output-files

# output_dir=~/spk-data
output_dir=$1

gp_dirs="Arabic Bulgarian Chinese-Shanghai/Wu Croatian Czech French German Japanese Korean Mandarin Polish Portuguese Russian Spanish Swedish Thai Turkish Vietnamese"
gp_dirs=($gp_dirs)
for d in "${gp_dirs[@]}"; do
  echo "Reading speakers from ${d}..."
  lang=$(echo "$d" | sed -E "s|.*/||")

  for spk_file in $d/spk/*; do
    spk_id=$(echo "$spk_file" | sed -E "s|(.*/)+[A-Z]+([0-9]+).spk|\2|")
    sex=$(cat "$spk_file" | grep -i "sex" | sed -E "s/.*:(.*)/\1/")
    dialect=$(cat "$spk_file" | grep -i "dialect" | sed -E "s/.*:(.*)/\1/")
    echo -e "${spk_id};${dialect};${sex}"
  done > "$output_dir/${lang}.csv"
done
