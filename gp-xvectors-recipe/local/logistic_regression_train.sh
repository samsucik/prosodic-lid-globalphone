#!/bin/bash
# Copyright  2014   David Snyder,  Daniel Povey
# Apache 2.0.
#
# This script trains a logistic regression model on top of
# X-vectors, and evaluates it on given set of test X-vectors.

. ./cmd.sh
. ./path.sh
set -e

## All these now provided as arguments when calling this script
prior_scale=1.0
conf="NONE" # conf/logistic-regression.conf
train_dir="NONE" # exp/ivectors_train
model_dir="NONE" # exp/ivectors_train
train_utt2lang="NONE" # data/train_lr/utt2lang
eval_utt2lang="NONE" # data/lre07/utt2lang
languages="NONE" # conf/test_languages.list

apply_log=true # If true, the output of the binary
               # logistitic-regression-eval are log-posteriors.
               # Probabilities are the output if this is false.

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

model=$model_dir/logistic_regression
model_rebalanced=$model_dir/logistic_regression_rebalanced
train_xvectors="ark:ivector-normalize-length scp:$train_dir/xvector.scp ark:- |"
classes="ark:cat $train_utt2lang | utils/sym2int.pl -f 2 $languages - |"

# Create priors to rebalance the model. The following script rebalances
# the languages as ( count(lang_test) / count(lang_train) )^(prior_scale).
echo "Re-balancing the model using non-uniform priors"
./local/balance_priors_to_test.pl \
    <(utils/filter_scp.pl -f 1 \
      $train_dir/xvector.scp $train_utt2lang) \
    <(cat $eval_utt2lang) \
    $languages \
    $prior_scale \
    $model_dir/priors.vec \
    2>$model_dir/balance-priors.log

echo "Training the log-reg model"
logistic-regression-train \
  --config=$conf \
  "$train_xvectors" \
  "$classes" \
  $model \
  2>$model_dir/logistic-regression-train.log

echo "Storing re-balanced trained model in $model_rebalanced"
logistic-regression-copy \
  --scale-priors=$model_dir/priors.vec \
  --print-args=false \
  $model \
  $model_rebalanced \
  2>$model_dir/logistic-regression-copy.log
