#!/bin/bash -u

partition=$1
echo "Calculating data amounts for the $partition set."
utt2len_file=mfcc/${partition}/utt2len

declare -A amts
for l in AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU VN WU; do
  amts[$l]=0
done

prev_lang="AR"

while IFS= read -r line
do
  utt_len=$(echo $line | sed -E "s/.*\s([0-9.]+)/\1/")
  lang=$(echo $line | sed -E "s/([A-Z]+).*/\1/")
  
  if [ ! "$prev_lang" == "$lang" ]; then
    echo "${prev_lang}: ${amts[$prev_lang]}"
    prev_lang=$lang
  fi

  # echo ">$lang<>$utt_len<"
  current=${amts[$lang]}
  updated=$(echo $current $utt_len | awk '{print $1 + $2}')  
  # echo "$lang: >$updated<"
  amts[$lang]=$updated
done < $utt2len_file

echo "${prev_lang}: ${amts[$prev_lang]}"
