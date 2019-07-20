#!/bin/bash -u

# Copyright 2019 Sam Sucik
# 
# Apache 2.0

# Calculates and prints out the total data amount (sum of segments length) separately for each
# language in the specified data partition. To be run from the directory one level up from the 
# experiment directories. 
#
# Usage (partition is 'train', 'enroll', 'eval' or 'test')
# ./get_data_amounts.sh partition

experiment_dir=mfcc
languages="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU VN WU"
prev_lang="AR"
partition=$1
echo "Calculating total amount of data (summing up segment lengths) for partition: ${partition}."
utt2len_file="${experiment_dir}/${partition}/utt2len"

declare -A amts
languages=($languages)
for l in "${languages[@]}"; do
  amts[$l]=0
done

while IFS= read -r line
do
  utt_len=$(echo "$line" | sed -E "s/.*\s([0-9.]+)/\1/")
  lang=$(echo "$line" | sed -E "s/([A-Z]+).*/\1/")
  
  if [ ! "$prev_lang" == "$lang" ]; then
    echo "${prev_lang}: ${amts[$prev_lang]}"
    prev_lang="$lang"
  fi

  current="${amts[$lang]}"
  updated=$(echo "$current" "$utt_len" | awk '{print $1 + $2}')  
  amts[$lang]="$updated"
done < "$utt2len_file"

echo "${prev_lang};${amts[$prev_lang]}"
