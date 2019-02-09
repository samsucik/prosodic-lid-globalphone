#!/bin/bash -u

# Copyright 2012  Arnab Ghoshal
#
# Copyright 2016 by Idiap Research Institute, http://www.idiap.ch
#
# Copyright 2018/2019 by Sam Sucik and Paul Moore
#
# See the file COPYING for the licence associated with this software.
#
# Author(s):
#   Bogdan Vlasenko, February 2016
#   Sam Sucik and Paul Moore, 2018/2019
#


# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.


usage="+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n
\t       This shell script runs the GlobalPhone+X-vectors recipe.\n
\t       Use like this: $0 <options>\n
\t       --stage=INT\t\tStage from which to start\n
\t       --run-all=(false|true)\tWhether to run all stages\n
\t       \t\t\tor just the specified one\n
\t       --experiment=STR\tExperiment name (also name of directory \n
\t       \t\t\twhere all files will be stored).\n
\t       \t\t\tDefault: 'baseline'.\n
\t       --exp-config=FILE\tConfig file with all kinds of options,\n
\t       \t\t\tsee conf/exp_default.conf for an example.\n
\t       \t\t\tNOTE: Where arguments are passed on the command line,\n
\t       \t\t\tthe values overwrite those found in the config file.\n\n
\t       If no stage number is provided, either all stages\n
\t       will be run (--run-all=true) or no stages at all.\n
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

# Default option values
exp_name="baseline"
stage=-1
run_all=false
exp_config=NONE
num_epochs=3
feature_type=mfcc
use_vad=true
recompute_vad=false

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --run-all=*)
  run_all_cl=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --stage=*)
  stage_cl=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --exp-name=*)
  exp_name_cl=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --exp-config=*)
  exp_config=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done
echo -e $usage

if [ ! "$exp_config" == "NONE" ] && [ ! -f $exp_config ]; then
  echo "Configuration file '${exp_config}' not found for this experiment."
  exit 1;
fi

# Source some variables from the experiment-specific config file
source $exp_config || echo "Problems sourcing the experiment config file: $exp_config"

# Use arguments passed to this script on the command line 
# to overwrite the values sourced from the experiment-specific config.
command_line_options="run_all stage exp_name"
for cl_opt in $command_line_options; do
  var="${cl_opt}_cl"
  if [[ -v $var ]]; then
    echo "Overwriting the experiment config value of ${cl_opt}=${!cl_opt}"\
      "using the value '${!var}' passed as a command-line argument."
    declare $cl_opt="${!var}"
  fi
done

echo "Running experiment: '$exp_name'"

if [ $stage -eq -1 ]; then
  if [ "$run_all" = true ]; then
    echo "No stage specified and --run-all=true, running all stages."
    stage=0
  else
    echo "No stage specified and --run-all=false, not running any stages."
  fi
else
  if [ "$run_all" = true ]; then
    echo "Running all stages starting with $stage."
  else
    echo "Running only stage $stage."
  fi
fi

[ -f helper_functions.sh ] && source ./helper_functions.sh \
  || echo "helper_functions.sh not found. Won't be able to set environment variables and similar."

[ -f conf/general_config.sh ] && source ./conf/general_config.sh \
  || echo "conf/general_config.sh not found or contains errors!"

[ -f conf/user_specific_config.sh ] && source ./conf/user_specific_config.sh \
  || echo "conf/user_specific_config.sh not found, create it by cloning " + \
          "conf/user_specific_config-example.sh"

[ -f cmd.sh ] && source ./cmd.sh || echo "cmd.sh not found. Jobs may not execute properly."

# CHECKING FOR AND INSTALLING REQUIRED TOOLS:
#  This recipe requires shorten (3.6.1) and sox (14.3.2).
#  If they are not found, the local/gp_install.sh script will install them.
./local/gp_check_tools.sh $PWD path.sh || exit 1;

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }

#if [ -d $DATADIR/$exp_name ]; then
#  echo "Experiment with name '$exp_name' already exists." \
#       "Continuing would overwrite it. Rename this experiment" \
#       "or backup/delete the old experiment directory '$DATADIR'."
#  exit 1
#fi

home_prefix=$DATADIR/$exp_name
train_data=$home_prefix/train
enroll_data=$home_prefix/enroll
eval_data=$home_prefix/eval
test_data=$home_prefix/test
log_dir=$home_prefix/log

mfcc_dir=$home_prefix/mfcc                   # vanilla MFCC
mfcc_sdc_dir=$home_prefix/mfcc_sdc           # MFCC for SDC (7D)
sdc_dir=$home_prefix/mfcc_sdc                # SDC

# Only if not specified this in the config
if [ -z "$mfcc_deltas_dir" ]; then
  mfcc_deltas_dir=$home_prefix/mfcc_deltas   # MFCC+deltas
fi
if [ -z "$pitch_energy_dir" ]; then
  pitch_energy_dir=$home_prefix/pitch_energy # Kaldi pitch + energy
fi
pitch_dir=$home_prefix/pitch                 # Kaldi pitch
energy_dir=$home_prefix/energy               # Raw energy
vaddir=$home_prefix/vad                      # any feature type ultimately run through VAD
vad_file_dir=$DATADIR/mfcc                   # The directory from which to take vad.scp (so 
                                             # the same VAD filtering can be done on any features)
mfcc_deltas_pitch_energy_dir=$home_prefix/mfcc_deltas_pitch_energy

feat_dir=$home_prefix/x_vector_features
nnet_train_data=$home_prefix/nnet_train_data
nnet_dir=$home_prefix/nnet
exp_dir=$home_prefix/exp

# If using existing preprocessed data for computing x-vectors
if [ ! -z "$use_dnn_egs_from" ]; then
  home_prefix=$DATADIR/$use_dnn_egs_from
  echo "Using preprocessed data	from: $home_prefix"

  if [ ! -d $home_prefix ]; then
    echo "ERROR: directory containging preprocessed data not found: '$home_prefix'"
    exit 1
  fi

  train_data=$home_prefix/train
  enroll_data=$home_prefix/enroll
  eval_data=$home_prefix/eval
  test_data=$home_prefix/test
  nnet_train_data=$home_prefix/nnet_train_data
  preprocessed_data_dir=$DATADIR/$use_dnn_egs_from
fi

DATADIR="${DATADIR}/$exp_name"
mkdir -p $DATADIR
mkdir -p $DATADIR/log
echo "The experiment directory is: $DATADIR"

# Set the languages that will actually be processed
GP_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU WU VN"
echo "Running with languages: ${GP_LANGUAGES}"

# The most time-consuming stage: Converting SHNs to WAVs. Should be done only once;
# then, this script can be run from stage 0 onwards.
if [ $stage -eq 42 ]; then
  echo "#### SPECIAL STAGE 42: Converting all SHN files to WAV files. ####"
  ./local/make_wavs.sh \
    --corpus-dir=$GP_CORPUS \
    --wav-dir=$HOME/lid/wav \
    --lang-map=$PWD/conf/lang_codes.txt \
    --languages="$GP_LANGUAGES"

  echo "Finished stage 42."
fi

# Preparing lists of utterances (and a couple other auxiliary lists) based
# on the train/enroll/eval/test splitting. The lists refer to the WAVs
# generated in the previous stage.
# Runtime: Under 2 mins
if [ $stage -eq 1 ]; then
  # NOTE: The wav-dir as it is right now only works in the cluster!
  echo "#### STAGE 1: Organising speakers into sets. ####"
  ./local/gp_data_organise.sh \
    --config-dir=$PWD/conf \
    --corpus-dir=$GP_CORPUS \
    --wav-dir=/mnt/mscteach_home/s1513472/lid/wav \
    --languages="$GP_LANGUAGES" \
    --data-dir=$DATADIR \
    || exit 1;

  # Don't split training data into segments. It will be split anyway when
  # preparing the training examples for the DNN. Note that the LID X-vector
  # paper has training segments of 2-4s.
  #  ./local/split_long_utts.sh \
  #    --max-utt-len 4 \
  #    $train_data \
  #    ${train_data}

  # Split enroll data into segments of < 30s.
  # TO-DO: Split into segments of various lengths (LID X-vector paper has 3-60s)
  ./local/split_long_utts.sh \
    --max-utt-len 30 \
    $enroll_data \
    ${enroll_data}

  # Split eval and testing utterances into segments of the same length (3s, 10s, 30s)
  # TO-DO: Allow for some variation, or do strictly this length?
  ./local/split_long_utts.sh \
    --max-utt-len 10 \
    $eval_data \
    ${eval_data}

  ./local/split_long_utts.sh \
    --max-utt-len 10 \
    $test_data \
    ${test_data}

  echo "Finished stage 1."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Make features and compute the energy-based VAD for each dataset
# Runtime: variable
if [ $stage -eq 2 ]; then
  echo "#### STAGE 2: features (MFCC, SDC, pitch, energy, etc) and VAD. ####"
  
  for data_subset in train enroll eval test; do
    (
    if [ "$feature_type" == "mfcc_deltas_pitch_energy" ]; then
      num_speakers=$(cat $mfcc_deltas_dir/${data_subset}/spk2utt | wc -l)
    else
      num_speakers=$(cat $DATADIR/${data_subset}/spk2utt | wc -l)
    fi    

    if [ "$num_speakers" -gt "$MAXNUMJOBS" ]; then
      num_jobs=$MAXNUMJOBS
    else
      num_jobs=$num_speakers
    fi
# : <<'END_COMMENT'
    # Runtime: ~12 mins
    if [ "$feature_type" == "mfcc" ]; then
      echo "Creating 23D MFCC features."
      steps/make_mfcc.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/mfcc.conf \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        --compress true \
        $DATADIR/${data_subset} \
        $log_dir/make_mfcc \
        $mfcc_dir
    # Runtime: > 12 minutes
    elif [ "$feature_type" == "mfcc_deltas" ]; then
      echo "Creating 23D MFCC features for MFCC-delta features."
      steps/make_mfcc.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/mfcc.conf \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        --compress true \
        $DATADIR/${data_subset} \
        $log_dir/make_mfcc \
        $mfcc_deltas_dir

      utils/fix_data_dir.sh $DATADIR/${data_subset}
      echo "Creating MFCC-delta features on top of 23D MFCC features."
      ./local/make_deltas.sh \
        --write-utt2num-frames false \
        --deltas-config conf/deltas.conf \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        --compress true \
        $DATADIR/${data_subset} \
        $log_dir/make_deltas \
        $mfcc_deltas_dir
    # Runtime: ??
    elif [ "$feature_type" == "sdc" ]; then
      echo "Creating 7D MFCC features for SDC features."
      steps/make_mfcc.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/mfcc_sdc.conf \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        --compress true \
        $DATADIR/${data_subset} \
        $log_dir/make_mfcc_sdc \
        $mfcc_sdc_dir

      utils/fix_data_dir.sh $DATADIR/${data_subset}

      echo "Creating SDC features on top of 7D MFCC features."
      ./local/make_sdc.sh \
        --write-utt2num-frames false \
        --sdc-config conf/sdc.conf \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        --compress true \
        $DATADIR/${data_subset} \
        $log_dir/make_sdc \
        $sdc_dir
    # Runtime: ~20 minutes
    elif [ "$feature_type" == "pitch_energy" ]; then
      echo "Creating 5D KaldiPitch + energy features."
      steps/make_mfcc_pitch.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/mfcc_energy.conf \
        --pitch-config conf/kaldi_pitch.conf \
        --pitch-postprocess-config conf/kaldi_pitch_process.conf \
        --paste-length-tolerance 2 \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        --compress true \
        $DATADIR/${data_subset} \
        $log_dir/make_pitch_energy \
        $pitch_energy_dir
    # Runtime: ~10 minutes
    elif [ "$feature_type" == "energy" ]; then
      echo "Creating 1D raw energy features."
      steps/make_mfcc.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/mfcc_energy.conf \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        --compress true \
        $DATADIR/${data_subset} \
        $log_dir/make_energy \
        $energy_dir
    # Runtime: ~14 minutes
    elif [ "$feature_type" == "pitch" ]; then
      echo "Creating 4D KaldiPitch features."
      ./local/make_pitch.sh \
        --write-utt2num-frames false \
        --pitch-config conf/kaldi_pitch.conf \
        --pitch-postprocess-config conf/kaldi_pitch_process.conf \
        --config conf/kaldi_pitch_compute_process.conf \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        --compress true \
        $DATADIR/${data_subset} \
        $log_dir/make_pitch \
        $pitch_dir
    # Runtime: ~40 minutes
    elif [ "$feature_type" == "mfcc_deltas_pitch_energy" ]; then
      echo "Creating 74D MFCC+deltas+delta-deltas+KaldiPitch+energy features."
      ./local/combine_feats.sh \
        --feature-name $feature_type \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        $mfcc_deltas_dir/${data_subset} \
        $pitch_energy_dir/${data_subset} \
        $DATADIR/${data_subset}
    fi
# END_COMMENT

    echo "Computing utt2num_frames and fixing the directory."
    
    # Have to calculate this separately, since make_mfcc.sh isn't writing properly
    utils/data/get_utt2num_frames.sh $DATADIR/${data_subset}
    utils/fix_data_dir.sh $DATADIR/${data_subset}

    if [[ $recompute_vad == true ]] || [ -z "$vad_file_dir" ] ; then
      echo "Re-computing VAD."
      ./local/compute_vad_decision.sh \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        $DATADIR/${data_subset} \
        $log_dir/make_vad \
        $vaddir

      utils/fix_data_dir.sh $DATADIR/${data_subset}
    else
      vad_file=$vad_file_dir/${data_subset}/vad.scp
      if [ ! -f "$vad_file" ]; then
        echo "Couldn't find existing VAD file: '${vad_file}'. Make sure it exists."
        exit 1
      else
        echo "Using existing VAD file: ${vad_file}"
        cp $vad_file $DATADIR/${data_subset}
      fi        
    fi

    ) &> $log_dir/${feature_type}_${data_subset}
  done

  echo "Finished stage 2."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Now we prepare the features to generate examples for xvector training.
# Runtime: ~2 mins
if [ $stage -eq 3 ]; then
  # NOTE silence not being removed
  echo "#### STAGE 3: Preprocessing for X-vector training examples. ####"
  
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  remove_nonspeech="$use_vad"
  ./local/prepare_feats_for_egs.sh \
    --nj $MAXNUMJOBS \
    --cmd "$preprocess_cmd" \
    --remove-nonspeech "$remove_nonspeech" \
    $train_data \
    $nnet_train_data \
    $feat_dir

	utils/data/get_utt2num_frames.sh $nnet_train_data
  utils/fix_data_dir.sh $nnet_train_data

  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
	echo "Removing short features..."
  min_len=500
  mv $nnet_train_data/utt2num_frames $nnet_train_data/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' $nnet_train_data/utt2num_frames.bak > $nnet_train_data/utt2num_frames
  utils/filter_scp.pl $nnet_train_data/utt2num_frames $nnet_train_data/utt2spk > $nnet_train_data/utt2spk.new
  mv $nnet_train_data/utt2spk.new $nnet_train_data/utt2spk
  utils/fix_data_dir.sh $nnet_train_data

  echo "Finished stage 3."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# NOTE main things we need to work on are the num-repeats and num-jobs parameters
# Runtime: ~19.5 hours
# TO-DO: Find out the runtime without using GPUs.
if [ $stage -eq 4 ]; then
  echo "#### STAGE 4: Training the X-vector DNN. ####"
  if [ ! -z "$use_dnn_egs_from" ]; then
    ./local/run_xvector.sh \
      --stage 5 \
      --train-stage -1 \
      --num-epochs $num_epochs \
      --max-num-jobs $MAXNUMJOBS \
      --data $nnet_train_data \
      --nnet-dir $nnet_dir \
      --egs-dir $preprocessed_data_dir/nnet/egs
  else
    ./local/run_xvector.sh \
      --stage 4 \
      --train-stage -1 \
      --num-epochs $num_epochs \
      --max-num-jobs $MAXNUMJOBS \
      --data $nnet_train_data \
      --nnet-dir $nnet_dir \
      --egs-dir $nnet_dir/egs
  fi

  echo "Finished stage 4."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 3`
  else
    exit
  fi
fi

# Runtime: ~1:05h. ~45min for MFCC+deltas+pitch+energy (because less data)
if [ $stage -eq 7 ]; then
  echo "#### STAGE 7: Extracting X-vectors from the trained DNN. ####"

  if [[ $(whichMachine) == cluster* ]]; then
    use_gpu=true
  else
    use_gpu=false
  fi
  remove_nonspeech="$use_vad"

  # X-vectors for training the classifier
  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    --stage 0 \
    --remove-nonspeech "$remove_nonspeech" \
    $nnet_dir \
    $enroll_data \
    $exp_dir/xvectors_enroll &

  # X-vectors for end-to-end evaluation
  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    --stage 0 \
    --remove-nonspeech "$remove_nonspeech" \
    $nnet_dir \
    $eval_data \
    $exp_dir/xvectors_eval &

  # X-vectors for testing (final evaluation)
#  ./local/extract_xvectors.sh \
#    --cmd "$extract_cmd --mem 6G" \
#    --use-gpu $use_gpu \
#    --nj $MAXNUMJOBS \
#    --stage 0 \
#    --remove-nonspeech "$remove_nonspeech" \
#    $nnet_dir \
#    $test_data \
#    $exp_dir/xvectors_test &

  wait;

  echo "Finished stage 7."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Using logistic regression as a classifier (adapted from egs/lre07/v2,
# described in https://arxiv.org/pdf/1804.05000.pdf)
# Runtime: ~ 3min
if [ $stage -eq 8 ]; then
  echo "#### STAGE 8: Training logistic regression classifier and classifying test utterances. ####"
  # Make language-int map (essentially just indexing the languages 0 to L)
  langs=($GP_LANGUAGES)
  i=0
  for l in "${langs[@]}"; do
    echo $l $i
    i=$(expr $i + 1)
  done > conf/test_languages.list

  mkdir -p $exp_dir/results
  mkdir -p $exp_dir/classifier

  # Training the log reg model and classifying test set samples
  ./local/run_logistic_regression.sh \
    --prior-scale 0.70 \
    --conf conf/logistic-regression.conf \
    --train-dir $exp_dir/xvectors_enroll \
    --test-dir $exp_dir/xvectors_eval \
    --model-dir $exp_dir/classifier \
    --classification-file $exp_dir/results/classification \
    --train-utt2lang $enroll_data/utt2lang \
    --test-utt2lang $eval_data/utt2lang \
    --languages conf/test_languages.list \
    &> $exp_dir/classifier/logistic-regression.log

  echo "Finished stage 8."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Runtime: < 10s
if [ $stage -eq 9 ]; then
  echo "#### STAGE 9: Calculating results. ####"

  ./local/compute_results.py \
    --classification-file $exp_dir/results/classification \
    --output-file $exp_dir/results/results \
    --language-list "$GP_LANGUAGES" \
    &>$exp_dir/results/compute_results.log

  echo "Finished stage 9."
fi
