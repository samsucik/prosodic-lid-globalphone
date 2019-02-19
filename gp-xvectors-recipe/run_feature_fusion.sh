#!/bin/bash -u

feat1=mfcc
feat2=pitch
use_test_set=false

if [ -f path.sh ]; then source ./path.sh; fi
source parse_options.sh || exit 1;

if [ $# -lt 2 ]; then
   echo "Usage: $0 [options] <feat1> <feat2>";
   echo "e.g.: $0 mfcc pitch_energy"
   echo " Options:"
   echo "  --use-test-set <bool|false>  # Whether to do scoring on the test set as well (in addition to eval set)"
   exit 1;
else
  feat1=$1
  feat2=$2
fi
log_prefix="\n$0"

echo -e "${log_prefix}Doing fusion of ${feat1} and ${feat2}."

GP_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU WU VN"
exp_dir=exp/fusion_${feat1}_${feat2}
classifier_dir=$exp_dir/classifier
exp_base_dir=~/lid

echo -e "${log_prefix}Storing everything in ${exp_dir}."

feat1_dir=$exp_base_dir/$feat1
feat2_dir=$exp_base_dir/$feat2

mkdir -p exp
mkdir -p $exp_dir
mkdir -p $exp_dir/results
mkdir -p $classifier_dir

if [ "$use_test_set" = true ]; then
  $datasets="enroll eval test"
else
  $datasets="enroll eval"
fi

for dataset in $datasets; do
  echo -e "${log_prefix}Concatenating ${dataset} xvectors..."
  
  mkdir -p $exp_dir/xvectors_${dataset}
  cp $feat1_dir/exp/xvectors_${dataset}/utt2lang $exp_dir/xvectors_${dataset}
  xvectors1=$feat1_dir/exp/xvectors_${dataset}/xvector.scp
  xvectors2=$feat2_dir/exp/xvectors_${dataset}/xvector.scp

  (
  paste-feats \
    ark:"copy-vector scp:$xvectors1 ark,t:- | sed -E 's/\[/\[\n/' | sed -E 's/\]/\n\]/' |" \
    ark:"copy-vector scp:$xvectors2 ark,t:- | sed -E 's/\[/\[\n/' | sed -E 's/\]/\n\]/' |" \
    ark,t:$exp_dir/xvectors_${dataset}/xvector_tmp.ark
  
  sed -i ':a;N;$!ba;s/\[\n/\[/g' $exp_dir/xvectors_${dataset}/xvector_tmp.ark

  copy-vector ark,t:$exp_dir/xvectors_${dataset}/xvector_tmp.ark \
    ark,scp:$exp_dir/xvectors_${dataset}/xvector.ark,$exp_dir/xvectors_${dataset}/xvector.scp
  ) > $exp_dir/concat_xvectors_${dataset}.log
done


langs=($GP_LANGUAGES)
i=0
for l in "${langs[@]}"; do
  echo $l $i
  i=$(expr $i + 1)
done > conf/test_languages.list

echo -e "${log_prefix} Training the log reg model..."
./local/logistic_regression_train.sh \
  --prior-scale 0.70 \
  --conf conf/logistic-regression.conf \
  --train-dir $exp_dir/xvectors_enroll \
  --model-dir $classifier_dir \
  --train-utt2lang $exp_dir/xvectors_enroll/utt2lang \
  --eval-utt2lang $exp_dir/xvectors_eval/utt2lang \
  --languages conf/test_languages.list \
  &> $exp_dir/classifier/logistic-regression-train.log



if [ "$use_test_set" = true ]; then
  $datasets="eval test"
else
  $datasets="eval"
fi

for dataset in $datasets; do
  echo -e "${log_prefix}Scoring eval set samples..."
  ./local/logistic_regression_score.sh \
    --languages conf/test_languages.list \
    --model-dir $classifier_dir \
    --test-dir $exp_dir/xvectors_${dataset} \
    --classification-file $exp_dir/results/classification-${dataset} \
    &> $exp_dir/classifier/logistic-regression-score-${dataset}.log

  echo -e "${log_prefix}Computing results..."
  ./local/compute_results.py \
    --classification-file $exp_dir/results/classification-${dataset} \
    --output-file $exp_dir/results/results-${dataset} \
    --conf-mtrx-file $exp_dir/results/conf_matrix-${dataset}.csv \
    --language-list "$GP_LANGUAGES" \
    &>$exp_dir/results/compute_results-${dataset}.log
fi
