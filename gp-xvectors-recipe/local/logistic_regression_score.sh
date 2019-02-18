#!/bin/bash -u

model_dir="NONE" # exp/ivectors_train
languages="NONE" # conf/test_languages.list
classification_file="NONE" # $train/test_dir/output
test_dir="NONE" # exp/ivectors_lre07

apply_log=true # If true, the output of the binary
               # logistitic-regression-eval are log-posteriors.
               # Probabilities are the output if this is false.

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

model_rebalanced=$model_dir/logistic_regression_rebalanced
test_xvectors="ark:ivector-normalize-length scp:$test_dir/xvector.scp ark:- |"


# Evaluate on test data.
echo "Classifying test utterances"
logistic-regression-eval \
  --apply-log=$apply_log \
  --print-args=false \
  $model_rebalanced \
  "$test_xvectors" \
  ark,t:$model_dir/posteriors \
  2>$model_dir/logistic-regression-eval.log

cat $model_dir/posteriors | \
  awk '{max=$3; argmax=3; for(f=3;f<NF;f++) { if ($f>max)
                          { max=$f; argmax=f; }}
                          print $1, (argmax - 3); }' | \
  utils/int2sym.pl -f 2 $languages \
    >$classification_file
