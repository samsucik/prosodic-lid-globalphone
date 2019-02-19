#!/bin/bash -u

source path.sh

GP_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU WU VN"
exp_dir=exp/xvectors_fusion
classifier_dir=$exp_dir/classifier

exp1=~/lid/mfcc
exp2=~/lid/pitch_energy

mkdir -p exp
mkdir -p $exp_dir
mkdir -p $exp_dir/results
mkdir -p $classifier_dir

for dataset in enroll eval; do
  echo "Concatenating ${dataset} xvectors..."
  
  mkdir -p $exp_dir/xvectors_${dataset}
  cp $exp1/exp/xvectors_${dataset}/utt2lang $exp_dir/xvectors_${dataset}
  xvectors1=$exp1/exp/xvectors_${dataset}/xvector.scp
  xvectors2=$exp2/exp/xvectors_${dataset}/xvector.scp

  echo "$xvectors1"
  echo "$xvectors2"

  paste-feats \
    ark:"copy-vector scp:$xvectors1 ark,t:- | sed -E 's/\[/\[\n/' | sed -E 's/\]/\n\]/' |" \
    ark:"copy-vector scp:$xvectors2 ark,t:- | sed -E 's/\[/\[\n/' | sed -E 's/\]/\n\]/' |" \
    ark,t:$exp_dir/xvectors_${dataset}/xvector_tmp.ark
  
  sed -i ':a;N;$!ba;s/\[\n/\[/g' $exp_dir/xvectors_${dataset}/xvector_tmp.ark

  copy-vector ark,t:$exp_dir/xvectors_${dataset}/xvector_tmp.ark \
    ark,scp:$exp_dir/xvectors_${dataset}/xvector.ark,$exp_dir/xvectors_${dataset}/xvector.scp
done

langs=($GP_LANGUAGES)
i=0
for l in "${langs[@]}"; do
  echo $l $i
  i=$(expr $i + 1)
done > conf/test_languages.list

# Training the log reg model
./local/logistic_regression_train.sh \
  --prior-scale 0.70 \
  --conf conf/logistic-regression.conf \
  --train-dir $exp_dir/xvectors_enroll \
  --model-dir $classifier_dir \
  --train-utt2lang $exp_dir/xvectors_enroll/utt2lang \
  --eval-utt2lang $exp_dir/xvectors_eval/utt2lang \
  --languages conf/test_languages.list \
  &> $exp_dir/classifier/logistic-regression-train.log
  
# Classifying eval set samples
./local/logistic_regression_score.sh \
  --languages conf/test_languages.list \
  --model-dir $classifier_dir \
  --test-dir $exp_dir/xvectors_eval \
  --classification-file $exp_dir/results/classification-eval \
  &> $exp_dir/classifier/logistic-regression-score-eval.log

# Computing results
./local/compute_results.py \
  --classification-file $exp_dir/results/classification-eval \
  --output-file $exp_dir/results/results-eval \
  --conf-mtrx-file $exp_dir/results/conf_matrix-eval.csv \
  --language-list "$GP_LANGUAGES" \
  &>$exp_dir/results/compute_results-eval.log
