#!/bin/bash -u

# Scrapes the speaker list from each partition 
# and compiles a LaTeX table summarising them.
# Run from inside the conf/ directory of the project.

echo "language & enrollment & evaluation & testing & training \\\\"

for l in `seq 1 19`; do 
  # echo $l; 
  train_l=$(sed "${l}q;d" train_spk.list | sed -E "s/[A-Z]+\s+//"); 
  enroll_l=$(sed "${l}q;d" enroll_spk.list | sed -E "s/[A-Z]+\s+//" | sed -E "s/\s+/, /g");
  eval_l=$(sed "${l}q;d" eval_spk.list | sed -E "s/[A-Z]+\s+//" | sed -E "s/\s+/, /g"); 
  test_l=$(sed "${l}q;d" test_spk.list | sed -E "s/[A-Z]+\s+//" | sed -E "s/\s+/, /g");
  lang=$(sed "${l}q;d" test_spk.list | sed -E "s/([A-Z]+).*/\1/");
  train_spks=($train_l);
  num_train=${#train_spks[@]}

  echo "${lang} & ${num_train} & ${enroll_l} & ${eval_l} & ${test_l} \\\\"
  echo "\\hline"
done
