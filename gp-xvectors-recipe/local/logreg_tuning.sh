#!/bin/bash -u

# Use to investigae values for logistic regression.
# Stores results in expname/results

GP_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU WU VN"

source ../path.sh

declare -a max_steps_vals=(20 40 60 80 100 120 140 160 180 200)
declare -a normalizer_vals=(0 0.00001 0.0001 0.001 0.01)
declare -a mix_up_vals=(19 50 100 150 200 250 300)

DATADIR="${DATADIR}/baseline"
exp_dir=$DATADIR/exp

langs=($GP_LANGUAGES)
i=0
for l in "${langs[@]}"; do
  echo $l $i
  i=$(expr $i + 1)
done > ../conf/test_languages.list

log_dir=$DATADIR/logreg_tuning
mkdir -p $log_dir

#:<<TEMP
for max_steps in ${max_steps_vals[@]}; do
  for normalizer in ${normalizer_vals[@]}; do
    for mix_up in ${mix_up_vals[@]}; do
      EXPNAME="max_steps=${max_steps}_normalizer=${normalizer}_mix_up=${mix_up}"
      test_dir=$DATADIR/logreg_tuning/$EXPNAME

      echo "#### Training logistic regression classifier and classifying test utterances. ####"
      echo "Max-steps = ${max_steps}, normalizer = ${normalizer}, mix-up = ${mix_up}"
      mkdir -p $test_dir/results
      mkdir -p $test_dir/classifier

      logistic_regression_conf_text="--max-steps=${max_steps}\n--normalizer=${normalizer}\n--mix-up=${mix_up}\n--power=0.15"
      echo -e $logistic_regression_conf_text > $test_dir/logistic-regression.conf
      
      (
      # Training the log reg model and classifying test set samples
      ./run_logistic_regression.sh \
        --prior-scale 0.70 \
        --conf $test_dir/logistic-regression.conf \
        --train-dir $exp_dir/xvectors_enroll \
        --test-dir $exp_dir/xvectors_eval \
        --model-dir $test_dir/classifier \
        --classification-file $test_dir/results/classification \
        --train-utt2lang $DATADIR/enroll/utt2lang \
        --test-utt2lang $DATADIR/eval/utt2lang \
        --languages ../conf/test_languages.list \
        > $test_dir/classifier/logistic-regression.log

      ./compute_results.py \
        --classification-file $test_dir/results/classification \
        --output-file $test_dir/results/results \
        --language-list "$GP_LANGUAGES" \
        2>$test_dir/results/compute_results.log
      ) &
    done
  done
done
wait
#TEMP


echo "Now putting together the results of all the runs."
:> $log_dir/results.log

for max_steps in ${max_steps_vals[@]}; do
  for normalizer in ${normalizer_vals[@]}; do
    for mix_up in ${mix_up_vals[@]}; do
      EXPNAME="max_steps=${max_steps}_normalizer=${normalizer}_mix_up=${mix_up}"
      test_dir=$DATADIR/logreg_tuning/$EXPNAME
      acc=$(cat $test_dir/results/results | grep "Accuracy" | sed -E "s/[^0-9]+([0-9.]+).*/\1/")
      c_primary=$(cat $test_dir/results/results | grep "C_primary" | sed -E "s/[^0-9]*([0-9.]+).*/\1/")
      echo "max-steps=${max_steps}, normalizer=${normalizer}, mix-up=${mix_up}, acc=${acc}, c_prim=${c_primary}" >> $log_dir/results.log
    done
  done
done
#TEMP
