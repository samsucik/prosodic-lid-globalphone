#!/bin/bash -u

# Copyright 2019 Sam Sucik
# 
# Apache 2.0

for d in Arabic Bulgarian Chinese-Shanghai/Wu Croatian Czech French German Japanese Korean Mandarin Polish Portuguese Russian Spanish Swedish Thai Turkish Vietnamese; do
  echo $d
  lang=$(echo $d | sed -E "s|.*/||")

  for spk_file in $d/spk/*; do
    spk_id=$(echo $spk_file | sed -E "s|(.*/)+[A-Z]+([0-9]+).spk|\2|")
    sex=$(cat $spk_file | grep -i "sex" | sed -E "s/.*:(.*)/\1/")
    dialect=$(cat $spk_file | grep -i "dialect" | sed -E "s/.*:(.*)/\1/")
    # echo -e "${spk_id}\t${dialect}"
    echo -e "${spk_id}\t${sex}"
  done > ~/gp-sexdata/$lang

done
