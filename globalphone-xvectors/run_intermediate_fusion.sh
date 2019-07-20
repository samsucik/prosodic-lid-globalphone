#!/bin/bash -u

# Copyright 2019 Sam Sucik
# 
# Apache 2.0

# Do x-vector fusion (fusing x-vectors from 2 or 3 feature types together). Requires the x-vectors
# to be already computed. For 10s segments, trains the classifier from scratch. For 3s segments, 
# requires a trained classifier (trained on 10s segments). Optionally, evaluates not just on the
# eval but also on the test data.

feat1=mfcc
feat2=pitch
feat3=
num_feats=2
use_test_set=false
test_3s=false
GP_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU WU VN"

# directory in which the relevant experiment directories are placed (xvectors will be taken from these)
exp_base_dir=~/lid 

# directory in which the directory for data and results relevant to this x-vector fusion experiment
# will be created
output_dir=exp

if [ -f path.sh ]; then source ./path.sh; fi
source parse_options.sh || exit 1;

if [ $# -lt 2 ]; then
  echo "Usage: $0 [options] <feat1> <feat2> [<feat3>]";
  echo "e.g.: $0 --test-3s true mfcc pitch energy"
  echo " Options:"
  echo "  --use-test-set <bool|false>  # Whether to do scoring on the test set as well (in addition to eval set)."
  echo "  --test-3s      <bool|false>  # If true, score on the 3s speech segments, use only the test set and take "
  echo "                               # pre-trained classifier from corresponding directory for 10s segments."
  echo "  --output-dir   DIR           # here the directory for data and results will be created"
  echo "  --exp-base-dir DIR           # here the experiment dirs with pre-computed x-vectors should be available"
  echo "  --feat[1,2,3]  string        # the names of 2 or 3 feature types to fuse"
  exit 1;
else
  feat1="$1"
  feat2="$2"
  if [ $# -gt 2 ]; then
    feat3="$3"
    num_feats=3
  fi
fi

log_prefix="\n$0: "
if [ $num_feats -eq 2 ]; then
  echo -e "${log_prefix}Doing x-vector fusion of ${feat1} and ${feat2}."
else
  echo -e "${log_prefix}Doing x-vector fusion of ${feat1}, ${feat2} and ${feat3}."
fi

if [ $num_feats -eq 2 ]; then
  exp_dir="${output_dir}/fusion_${feat1}+${feat2}"
else
  exp_dir="${output_dir}/fusion_${feat1}+${feat2}+${feat3}"
fi
echo -e "${log_prefix}Storing all data and results in ${exp_dir}"

classifier_dir="$exp_dir/classifier"
if [ "$test_3s" = true ]; then
  exp_dir="${exp_dir}-3s"
  if [ ! -d "$classifier_dir" ]; then
    echo -e "${log_prefix}Directory ${classifier_dir} has to exist (and should contain a pre-trained classifier)!"
    exit 1
  fi
  echo -e "${log_prefix}Only scoring (on 3s segments) with pre-trained classifier taken from ${classifier_dir}."
else
  echo -e "${log_prefix}Both training the classifier and scoring (on 10s segments)."
fi

feat1_dir="$exp_base_dir/$feat1"
feat2_dir="$exp_base_dir/$feat2"
feat3_dir="$exp_base_dir/$feat3"

if [ "$test_3s" = true ]; then
  feat1_dir="${feat1_dir}-3s"
  feat2_dir="${feat2_dir}-3s"
  feat3_dir="${feat3_dir}-3s"
fi

mkdir -p exp
mkdir -p "$exp_dir"
mkdir -p "$exp_dir/results"

if [ "$test_3s" = false ]; then
  mkdir -p "$classifier_dir"
else
  mkdir -p "$exp_dir/classifier"
fi

if [ "$test_3s" = true ]; then
  datasets="test"
elif [ "$use_test_set" = true ]; then
  datasets="enroll eval test"
else
  datasets="enroll eval"
fi

for dataset in $datasets; do
  echo -e "${log_prefix}Concatenating ${dataset} xvectors..."
  
  mkdir -p "$exp_dir/xvectors_${dataset}"
  cp "$feat1_dir/exp/xvectors_${dataset}/utt2lang" "$exp_dir/xvectors_${dataset}"
  xvectors1="$feat1_dir/exp/xvectors_${dataset}/xvector.scp"
  xvectors2="$feat2_dir/exp/xvectors_${dataset}/xvector.scp"

  if [ $num_feats -eq 3 ]; then
    xvectors3="$feat3_dir/exp/xvectors_${dataset}/xvector.scp"
  fi

  (
    if [ $num_feats -eq 2 ]; then
      paste-feats \
        ark:"copy-vector scp:$xvectors1 ark,t:- | sed -E 's/\[/\[\n/' | sed -E 's/\]/\n\]/' |" \
        ark:"copy-vector scp:$xvectors2 ark,t:- | sed -E 's/\[/\[\n/' | sed -E 's/\]/\n\]/' |" \
        ark,t:"$exp_dir/xvectors_${dataset}/xvector_tmp.ark"
    else
      paste-feats \
        ark:"copy-vector scp:$xvectors1 ark,t:- | sed -E 's/\[/\[\n/' | sed -E 's/\]/\n\]/' |" \
        ark:"copy-vector scp:$xvectors2 ark,t:- | sed -E 's/\[/\[\n/' | sed -E 's/\]/\n\]/' |" \
        ark:"copy-vector scp:$xvectors3 ark,t:- | sed -E 's/\[/\[\n/' | sed -E 's/\]/\n\]/' |" \
        ark,t:"$exp_dir/xvectors_${dataset}/xvector_tmp.ark"
    fi

    sed -i ':a;N;$!ba;s/\[\n/\[/g' "$exp_dir/xvectors_${dataset}/xvector_tmp.ark"

    copy-vector ark,t:"$exp_dir/xvectors_${dataset}/xvector_tmp.ark" \
      ark,scp:"$exp_dir/xvectors_${dataset}/xvector.ark,$exp_dir/xvectors_${dataset}/xvector.scp"
  ) &> "$exp_dir/concat_xvectors_${dataset}.log"
done

langs=($GP_LANGUAGES)
i=0
for l in "${langs[@]}"; do
  echo $l $i
  i=$(expr $i + 1)
done > "$exp_dir/test_languages.list"

if [ "$test_3s" = false ]; then
  echo -e "${log_prefix} Training the log reg model..."
  ./local/logistic_regression_train.sh \
    --prior-scale 0.70 \
    --conf conf/logistic-regression.conf \
    --train-dir "$exp_dir/xvectors_enroll" \
    --model-dir "$classifier_dir" \
    --train-utt2lang "$exp_dir/xvectors_enroll/utt2lang" \
    --eval-utt2lang "$exp_dir/xvectors_eval/utt2lang" \
    --languages "$exp_dir/test_languages.list" \
    &> "$exp_dir/classifier/logistic-regression-train.log"
fi

if [ "$test_3s" = true ]; then
  datasets="test"
elif [ "$use_test_set" = true ]; then
  datasets="eval test"
else
  datasets="eval"
fi

for dataset in $datasets; do
  echo -e "${log_prefix}Scoring ${dataset} set samples..."
  ./local/logistic_regression_score.sh \
    --languages "$exp_dir/test_languages.list" \
    --model-dir "$classifier_dir" \
    --test-dir "$exp_dir/xvectors_${dataset}" \
    --classification-file "$exp_dir/results/classification-${dataset}" \
    &> "$exp_dir/classifier/logistic-regression-score-${dataset}.log"

  echo -e "${log_prefix}Computing results..."
  ./local/compute_results.py \
    --classification-file "$exp_dir/results/classification-${dataset}" \
    --output-file "$exp_dir/results/results-${dataset}" \
    --conf-mtrx-file "$exp_dir/results/conf_matrix-${dataset}.csv" \
    --language-list "$GP_LANGUAGES" \
    &> "$exp_dir/results/compute_results-${dataset}.log"
done
