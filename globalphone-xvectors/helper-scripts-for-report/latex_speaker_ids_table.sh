#!/bin/bash -u

# Copyright 2019 Sam Sucik
# 
# Apache 2.0

# Creates a LaTeX table with speaker IDs in each data partition of each language. The data is 
# scraped from the speaker lists in the conf/ directory. For the training partition, only the
# number of speakers is printed (because printing all the IDs would inflate the table too much).
# 
# Usage: Run from the conf/ directory of the recipe.

num_languages=19
echo "language & enrollment & evaluation & testing & training \\\\"

for l in `seq 1 $num_languages`; do 
  train_l=$(sed "${l}q;d" train_spk.list | sed -E "s/[A-Z]+\s+//"); 
  enroll_l=$(sed "${l}q;d" enroll_spk.list | sed -E "s/[A-Z]+\s+//" | sed -E "s/\s+/, /g");
  eval_l=$(sed "${l}q;d" eval_spk.list | sed -E "s/[A-Z]+\s+//" | sed -E "s/\s+/, /g"); 
  test_l=$(sed "${l}q;d" test_spk.list | sed -E "s/[A-Z]+\s+//" | sed -E "s/\s+/, /g");
  lang=$(sed "${l}q;d" test_spk.list | sed -E "s/([A-Z]+).*/\1/");
  train_spks=($train_l);
  num_train="${#train_spks[@]}"

  echo "${lang} & ${num_train} & ${enroll_l} & ${eval_l} & ${test_l} \\\\"
  echo "\\hline"
done
