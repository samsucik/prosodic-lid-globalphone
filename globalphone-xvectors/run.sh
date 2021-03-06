#!/bin/bash -u

# Copyright 2019 Sam Sucik and Paul Moore
# 
# Apache 2.0

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
\t       \t\t\tNOTE: Where any of the run_all, stage, exp_name, \n
\t       \t\t\targuments are passed on the command line,\n
\t       \t\t\tthe values overwrite those from the config file.\n\n
\t       If no stage number is provided, either all stages\n
\t       will be run (--run-all=true) or no stages at all.\n
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"


####################################################################################################
## Setting configurable experiment options from configs and from the command line
####################################################################################################

# Get default option values from the default config if no config is specified.
exp_config=conf/exp_default.conf

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

if [ ! -f $exp_config ]; then
  echo -e "Config file for this experiment ('${exp_config}') not found. Trying to use the default 
  config from conf/exp_default.conf."
  exit 1;
fi

# Source experiment options from the experiment-specific config file
source $exp_config || {echo "Problems sourcing the experiment config file: ${exp_config}"; exit 1;}

# Use options passed to this script on the command line to overwrite the values sourced from the 
# experiment config file.
command_line_options="run_all stage exp_name"
for cl_opt in $command_line_options; do
  var="${cl_opt}_cl"
  if [[ -v $var ]]; then
    echo "Overwriting the experiment config value of ${cl_opt}=${!cl_opt}"\
      "using the value '${!var}' passed as a command-line argument."
    declare $cl_opt="${!var}"
  fi
done

echo "Running experiment: '${exp_name}'..."
echo "Using languages: ${GP_LANGUAGES}."

if [ $stage -eq -1 ]; then
  if [ "${run_all}" = true ]; then
    echo "No stage specified and --run-all=true, running all stages."
    stage=0
  else
    echo "No stage specified and --run-all=false, not running any stages."
  fi
else
  if [ "${run_all}" = true ]; then
    echo "Running all stages starting with stage ${stage}."
  else
    echo "Running only stage ${stage}."
  fi
fi

[ -f helper_functions.sh ] && source ./helper_functions.sh \
  || echo "helper_functions.sh not found. Won't be able to set environment variables and similar."

[ -f conf/general_config.sh ] && source ./conf/general_config.sh \
  || echo "conf/general_config.sh not found or contains errors!"

[ -f conf/user_specific_config.sh ] && source ./conf/user_specific_config.sh \
  || echo -e "conf/user_specific_config.sh not found, create it by cloning conf/user_specific_config-example.sh"

[ -f cmd.sh ] && source ./cmd.sh || echo "cmd.sh not found. Jobs may not execute properly."

# Checking for existing installations/installing required tools. This recipe requires shorten (3.6.1)
# and sox (14.3.2). If they are not found, the local/gp_install.sh script will try install them.
./local/gp_check_tools.sh $PWD path.sh || exit 1;

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }

if [ "${mode}" = test_only ]; then
  use_test_set=true
fi

home_prefix="$DATADIR/$exp_name"
train_data="$home_prefix/train"
enroll_data="$home_prefix/enroll"
eval_data="$home_prefix/eval"
test_data="$home_prefix/test"
log_dir="$home_prefix/log"

# If not specified in the experiment config file, all feature types will be taken from 
# the current experiment.
if [ -z ${mfcc_dir+x} ]; then
  mfcc_dir="$home_prefix/mfcc"                 # vanilla MFCC
fi
if [ -z ${sdc_dir+x} ]; then
  sdc_dir="$home_prefix/mfcc_sdc"              # SDC
fi
if [ -z ${mfcc_deltas_dir+x} ]; then
  mfcc_deltas_dir="$home_prefix/mfcc_deltas"   # MFCC+deltas
fi
if [ -z ${pitch_energy_dir+x} ]; then
  pitch_energy_dir="$home_prefix/pitch_energy" # Kaldi pitch + energy
fi
if [ -z ${pitch_dir+x} ]; then
  pitch_dir="$home_prefix/pitch"               # Kaldi pitch
fi
if [ -z ${energy_dir+x} ]; then
  energy_dir="$home_prefix/energy"             # (Raw) energy
fi

mfcc_sdc_dir="$home_prefix/mfcc_sdc"           # MFCC for SDC computation
vaddir="$home_prefix/vad"                      # Directory for storing computed features with VAD
                                               # applied to them.
vad_file_dir="$DATADIR/$exp_dir_for_vad"       # Directory from which to take vad.scp (so that the 
                                               # same VAD filtering can be done on any features).

feat_dir="$home_prefix/x_vector_features"      # Directory where computed features with CMVN and VAD
                                               # applied will be stored (ready to be processed into 
                                               # examples fed into the X-vector TDNN).
nnet_train_data="$home_prefix/nnet_train_data" # Directory where the actual training data for the
                                               # X-vector TDNN will be stored.

# Set directory where the trained X-vector TDNN will be stored.
if [ -z "${nnet_exp_dir}" ]; then
  nnet_dir="$home_prefix/nnet"
else
  nnet_dir="$nnet_exp_dir/nnet" # take trained TDNN from a different experiment
fi

exp_dir="$home_prefix/exp"

# If using existing computed features from another experiment (perhaps to save time by not 
# re-computing those), set the paths slightly differently:
if [ ! -z ${use_dnn_egs_from+x} ]; then
  home_prefix="$DATADIR/$use_dnn_egs_from"
  echo "Using preprocessed data	from: '${home_prefix}'"

  if [ ! -d $home_prefix ]; then
    echo "ERROR: directory containging preprocessed data not found: '${home_prefix}'"
    exit 1
  fi

  train_data="$home_prefix/train"
  enroll_data="$home_prefix/enroll"
  eval_data="$home_prefix/eval"
  test_data="$home_prefix/test"
  nnet_train_data="$home_prefix/nnet_train_data"
  preprocessed_data_dir="$DATADIR/$use_dnn_egs_from"
fi

# Create the experiment directory
DATADIR="${DATADIR}/$exp_name"
mkdir -p "${DATADIR}"
mkdir -p "${DATADIR}/log"
echo "The experiment directory is: '${DATADIR}'"


####################################################################################################
## Running the stages of an experiment
####################################################################################################

# The most time-consuming stage: Converting SHNs to WAVs. Should be done only once, not separately
# for each experiment. Then, all experiments can skip this stage and start from stage 1 instead.
# For each language, WAV files as well as spk, wav.scp, spk2utt, utt2spk, and utt2len lists are 
# created.
# Runtime: over 7 hours
if [ $stage -eq 42 ]; then
  echo "#### SPECIAL STAGE 42: Converting all SHN files to WAV files. ####"
  ./local/make_wavs.sh \
    --corpus-dir="$GP_CORPUS" \
    --wav-dir="$wav_dir" \
    --lang-map="$PWD/conf/lang_codes.txt" \
    --languages="$GP_LANGUAGES"

  echo "Finished stage 42."
fi

# Preparing lists of utterances (+ some other auxiliary lists) based on the train/enroll/eval/test 
# splitting. The lists point to the WAV files generated in the previous stage.
# The lists created (separately for each data partition) are: wav.scp, spk2utt, utt2spk, utt2len,
# utt2lang, lang2utt.
#
# Runtime: Under 2 mins
if [ $stage -eq 1 ]; then
  echo "#### STAGE 1: Creating speaker and utterance lists for each data partition. ####"
  ./local/gp_data_organise.sh \
    --config-dir="$PWD/conf" \
    --wav-dir="$wav_dir" \
    --languages="$GP_LANGUAGES" \
    --data-dir="$DATADIR" \
    || exit 1;

  if [ "$mode" = full ]; then
    # Split enroll data into segments of < 30s.
    # TO-DO: Split into segments of various lengths (LID X-vector paper has 3-60s)
    ./local/split_long_utts.sh \
      --max-utt-len 30 \
      "$enroll_data" \
      "$enroll_data"
  
    # Split eval and testing utterances into segments of the same length (e.g. 3s, 10s, 30s)
    # TO-DO: Allow for some variation, or do strictly this length?
    ./local/split_long_utts.sh \
      --max-utt-len "$eval_utt_len" \
      "$eval_data" \
      "$eval_data"
  fi

  ./local/split_long_utts.sh \
    --max-utt-len "$eval_utt_len" \
    "$test_data" \
    "$test_data"

  echo "Finished stage 1."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Compute features from WAVs and the energy-based VAD for each data partition.
# Runtime: variable
if [ $stage -eq 2 ]; then
  echo "#### STAGE 2: computing features and VAD. ####"

  # determine which data partitions to handle
  if [ "$mode" = full ]; then
    if [ "$use_test_set" = true ]; then
      partitions='train enroll eval test'
    else
      partitions='train enroll eval'
    fi
  else
    partitions='test'
  fi

  for data_subset in $partitions; do
  (         
    num_speakers=$(cat $DATADIR/${data_subset}/spk2utt | wc -l)
    
    if [ "$num_speakers" -gt "$MAXNUMJOBS" ]; then
      num_jobs="$MAXNUMJOBS"
    else
      num_jobs="$num_speakers"
    fi

    # Runtime: ~12 mins
    if [ "$feature_type" == "mfcc" ]; then
      echo "Creating 23D MFCC features."
      steps/make_mfcc.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/feature_configs/mfcc.conf \
        --nj "$num_jobs" \
        --cmd "$preprocess_cmd" \
        --compress true \
        "$DATADIR/${data_subset}" \
        "$log_dir/make_mfcc" \
        "$mfcc_dir"

    # Runtime: > 12 minutes
    elif [ "$feature_type" == "mfcc_deltas" ]; then
      echo "Creating 23D MFCC features for MFCC-delta features."
      steps/make_mfcc.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/feature_configs/mfcc.conf \
        --nj "$num_jobs" \
        --cmd "$preprocess_cmd" \
        --compress true \
        "$DATADIR/${data_subset}" \
        "$log_dir/make_mfcc" \
        "$mfcc_deltas_dir"
      utils/fix_data_dir.sh "$DATADIR/${data_subset}"
      echo "Creating 69D MFCC-delta features on top of 23D MFCC features."
      ./local/make_deltas.sh \
        --write-utt2num-frames false \
        --deltas-config conf/feature_configs/deltas.conf \
        --nj "$num_jobs" \
        --cmd "$preprocess_cmd" \
        --compress true \
        "$DATADIR/${data_subset}" \
        "$log_dir/make_deltas" \
        "$mfcc_deltas_dir"
    
    # Runtime: ??
    elif [ "$feature_type" == "sdc" ]; then
      echo "Creating 9D MFCC features for SDC features."
      steps/make_mfcc.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/feature_configs/mfcc_sdc.conf \
        --nj "$num_jobs" \
        --cmd "$preprocess_cmd" \
        --compress true \
        "$DATADIR/${data_subset}" \
        "$log_dir/make_mfcc_sdc" \
        "$mfcc_sdc_dir"
      utils/fix_data_dir.sh "$DATADIR/${data_subset}"
      echo "Creating 72D SDC features on top of 7D MFCC features."
      ./local/make_sdc.sh \
        --write-utt2num-frames false \
        --sdc-config conf/feature_configs/sdc.conf \
        --nj "$num_jobs" \
        --cmd "$preprocess_cmd" \
        --compress true \
        "$DATADIR/${data_subset}" \
        "$log_dir/make_sdc" \
        "$sdc_dir"

    # Runtime: ~20 minutes
    elif [ "$feature_type" == "pitch_energy" ]; then
      echo "Creating 5D KaldiPitch + energy features."
      steps/make_mfcc_pitch.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/feature_configs/mfcc_energy.conf \
        --pitch-config conf/feature_configs/kaldi_pitch.conf \
        --pitch-postprocess-config conf/feature_configs/kaldi_pitch_process.conf \
        --paste-length-tolerance 2 \
        --nj "$num_jobs" \
        --cmd "$preprocess_cmd" \
        --compress true \
        "$DATADIR/${data_subset}" \
        "$log_dir/make_pitch_energy" \
        "$pitch_energy_dir"
    
    # Runtime: ~10 minutes
    elif [ "$feature_type" == "energy" ]; then
      echo "Creating 1D raw energy features."
      steps/make_mfcc.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/feature_configs/mfcc_energy.conf \
        --nj "$num_jobs" \
        --cmd "$preprocess_cmd" \
        --compress true \
        "$DATADIR/${data_subset}" \
        "$log_dir/make_energy" \
        "$energy_dir"

    # Runtime: ~14 minutes
    elif [ "$feature_type" == "pitch" ]; then
      echo "Creating 4D KaldiPitch features."
      ./local/make_pitch.sh \
        --write-utt2num-frames false \
        --pitch-config conf/feature_configs/kaldi_pitch.conf \
        --pitch-postprocess-config conf/feature_configs/kaldi_pitch_process.conf \
        --nj "$num_jobs" \
        --cmd "$preprocess_cmd" \
        --compress true \
        "$DATADIR/${data_subset}" \
        "$log_dir/make_pitch" \
        "$pitch_dir"

    # Runtime: ~40 minutes
    elif [ "$feature_type" == "mfcc_deltas_pitch_energy" ]; then
      echo "Creating 74D MFCC+deltas+delta-deltas+KaldiPitch+energy features."
      ./local/combine_feats.sh \
        --feature-name "$feature_type" \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        "$mfcc_deltas_dir/${data_subset}" \
        "$pitch_energy_dir/${data_subset}" \
        "$DATADIR/${data_subset}"

    elif [ "$feature_type" == "mfcc_deltas_pitch" ]; then
      echo "Creating 73D MFCC+deltas+delta-deltas+KaldiPitch features."
      ./local/combine_feats.sh \
        --feature-name "$feature_type" \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        "$mfcc_deltas_dir/${data_subset}" \
        "$pitch_dir/${data_subset}" \
        "$DATADIR/${data_subset}"

    elif [ "$feature_type" == "mfcc_deltas_energy" ]; then
      echo "Creating 70D MFCC+deltas+delta-deltas+energy features."
      ./local/combine_feats.sh \
        --feature-name "$feature_type" \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        "$mfcc_deltas_dir/${data_subset}" \
        "$energy_dir/${data_subset}" \
        "$DATADIR/${data_subset}"

    elif [ "$feature_type" == "mfcc_pitch_energy" ]; then
      echo "Creating 28D MFCC+KaldiPitch+energy features."
      ./local/combine_feats.sh \
        --feature-name "$feature_type" \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        "$mfcc_dir/${data_subset}" \
        "$pitch_energy_dir/${data_subset}" \
        "$DATADIR/${data_subset}"

    elif [ "$feature_type" == "mfcc_pitch" ]; then
      echo "Creating 27D MFCC+KaldiPitch features."
      ./local/combine_feats.sh \
        --feature-name "$feature_type" \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        "$mfcc_dir/${data_subset}" \
        "$pitch_dir/${data_subset}" \
        "$DATADIR/${data_subset}"

    elif [ "$feature_type" == "mfcc_energy" ]; then
      echo "Creating 24D MFCC+energy features."
      ./local/combine_feats.sh \
        --feature-name "$feature_type" \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        "$mfcc_dir/${data_subset}" \
        "$energy_dir/${data_subset}" \
        "$DATADIR/${data_subset}"

    elif [ "$feature_type" == "sdc_pitch_energy" ]; then
      echo "Creating 77D SDC+KaldiPitch+energy features."
      ./local/combine_feats.sh \
        --feature-name "$feature_type" \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        "$sdc_dir/${data_subset}" \
        "$pitch_energy_dir/${data_subset}" \
        "$DATADIR/${data_subset}"

    elif [ "$feature_type" == "sdc_pitch" ]; then
      echo "Creating 76D SDC+KaldiPitch features."
      ./local/combine_feats.sh \
        --feature-name "$feature_type" \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        "$sdc_dir/${data_subset}" \
        "$pitch_dir/${data_subset}" \
        "$DATADIR/${data_subset}"

    elif [ "$feature_type" == "sdc_energy" ]; then
      echo "Creating 73D SDC+energy features."
      ./local/combine_feats.sh \
        --feature-name "$feature_type" \
        --paste-length-tolerance 2 \
        --cmd "$preprocess_cmd" \
        "$sdc_dir/${data_subset}" \
        "$energy_dir/${data_subset}" \
        "$DATADIR/${data_subset}"
    fi

    echo "Computing utt2num_frames and fixing the directory."
    # Have to calculate this separately, since make_mfcc.sh isn't writing properly
    utils/data/get_utt2num_frames.sh "$DATADIR/${data_subset}"
    utils/fix_data_dir.sh "$DATADIR/${data_subset}"

    if [[ $recompute_vad == true ]] || [ -z "$vad_file_dir" ] ; then
      echo "Re-computing VAD."
      ./local/compute_vad_decision.sh \
        --nj "$num_jobs" \
        --cmd "$preprocess_cmd" \
        --vad-config conf/feature_configs/vad.conf \
        "$DATADIR/${data_subset}" \
        "$log_dir/make_vad" \
        "$vaddir"

      utils/fix_data_dir.sh "$DATADIR/${data_subset}"
    else
      vad_file="$vad_file_dir/${data_subset}/vad.scp"
      if [ ! -f "$vad_file" ]; then
        echo "Couldn't find existing VAD file: '${vad_file}'. Make sure it exists."
        exit 1
      else
        echo "Using existing VAD file: ${vad_file}"
        cp "$vad_file" "$DATADIR/${data_subset}"
      fi        
    fi
  ) &> "$log_dir/${feature_type}_${data_subset}"
  done

  echo "Finished stage 2."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Feature post-processing of training data to create training examples for the X-vector TDNN.
# Runtime: ~2 mins
if [ $stage -eq 3 ] && [ "$mode" = full ]; then
  echo "#### STAGE 3: Post-processing training data features to create TDNN training examples. ####"
  
  # Apply CMN and maybe remove nonspeech frames based on the previously computed VAD. Note that 
  # this is somewhat wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  remove_nonspeech="$use_vad"
  ./local/prepare_feats_for_egs.sh \
    --nj "$MAXNUMJOBS" \
    --cmd "$preprocess_cmd" \
    --remove-nonspeech "$remove_nonspeech" \
    "$train_data" \
    "$nnet_train_data" \
    "$feat_dir"

	utils/data/get_utt2num_frames.sh "$nnet_train_data"
  utils/fix_data_dir.sh "$nnet_train_data"

  # Remove from the training utterances any that are shorter than 5s (500 frames).
	echo "Removing short features..."
  min_len=500
  mv "$nnet_train_data/utt2num_frames" "$nnet_train_data/utt2num_frames.bak"
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' \
    "$nnet_train_data/utt2num_frames.bak" > "$nnet_train_data/utt2num_frames"
  utils/filter_scp.pl "$nnet_train_data/utt2num_frames" "$nnet_train_data/utt2spk" \
    > "$nnet_train_data/utt2spk.new"
  mv "$nnet_train_data/utt2spk.new" "$nnet_train_data/utt2spk"
  utils/fix_data_dir.sh "$nnet_train_data"

  echo "Finished stage 3."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Training the X-vector TDNN.
# Runtime: ~19.5 hours (7 epochs, using 3 GeForce GTX 1060 6GB GPUs)
if [ $stage -eq 4 ] && [ "$mode" = full ]; then
  echo "#### STAGE 4: Training the X-vector DNN. ####"
  
  # If taking training examples from another experiment, skip stage 4 in the script (creating 
  # training archives -- effectively batches, including duplicating and shuffling the data).
  if [ ! -z "$use_dnn_egs_from" ]; then
    ./local/run_xvector.sh \
      --stage 5 \
      --train-stage -1 \
      --num-epochs "$num_epochs" \
      --max-num-jobs "$MAXNUMJOBS" \
      --data "$nnet_train_data" \
      --nnet-dir "$nnet_dir" \
      --egs-dir "$preprocessed_data_dir/nnet/egs"
  else
    ./local/run_xvector.sh \
      --stage 4 \
      --train-stage -1 \
      --num-epochs "$num_epochs" \
      --max-num-jobs "$MAXNUMJOBS" \
      --data "$nnet_train_data" \
      --nnet-dir "$nnet_dir" \
      --egs-dir "$nnet_dir/egs"
  fi

  echo "Finished stage 4."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 3`
  else
    exit
  fi
fi

# Extracting x-vectors for enrollment data (for training the classifier), and for evaluation and
# testing data.
# Runtime: variable. When running on 10 worker nodes in parallel, each with one GPU, takes ~1h to
# extract enrollment, evaluation and testing portion x-vectors. The more you can parallelize this
# stage (with many worker nodes available), the better.
if [ $stage -eq 7 ]; then
  echo "#### STAGE 7: Extracting X-vectors from the trained TDNN. ####"

  if [[ $(whichMachine) == cluster* ]]; then
    use_gpu=true
  else
    use_gpu=false
  fi
  remove_nonspeech="$use_vad"

  if [ "$mode" = full ]; then
    # X-vectors for training the classifier
    ./local/extract_xvectors.sh \
      --cmd "$extract_cmd --mem 6G" \
      --use-gpu "$use_gpu" \
      --nj "$MAXNUMJOBS" \
      --stage 0 \
      --remove-nonspeech "$remove_nonspeech" \
      "$nnet_dir" \
      "$enroll_data" \
      "$exp_dir/xvectors_enroll" &

    # X-vectors for end-to-end evaluation
    ./local/extract_xvectors.sh \
      --cmd "$extract_cmd --mem 6G" \
      --use-gpu "$use_gpu" \
      --nj "$MAXNUMJOBS" \
      --stage 0 \
      --remove-nonspeech "$remove_nonspeech" \
      "$nnet_dir" \
      "$eval_data" \
      "$exp_dir/xvectors_eval" &
  fi
  
  if [ "$use_test_set" = true ]; then
    # X-vectors for end-to-end testing
    ./local/extract_xvectors.sh \
      --cmd "$extract_cmd --mem 6G" \
      --use-gpu "$use_gpu" \
      --nj "$MAXNUMJOBS" \
      --stage 0 \
      --remove-nonspeech "$remove_nonspeech" \
      "$nnet_dir" \
      "$test_data" \
      "$exp_dir/xvectors_test" &
  fi

  wait # wait for all the x-vector extracting processes running in the background

  echo "Finished stage 7."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Training a mixture model classifier based on logistic regression (adapted from egs/lre07/v2,
# described in https://arxiv.org/pdf/1804.05000.pdf), and classifying the evaluation and testing
# utterances.
# Runtime: ~3min
if [ $stage -eq 8 ]; then
  echo "#### STAGE 8: Training logistic regression classifier & scoring eval/test utterances. ####"
  # Make language-int map (essentially just indexing the languages 0 to L)
  langs=($GP_LANGUAGES)
  lang_map_file=conf/test_languages.list
  i=0
  for l in "${langs[@]}"; do
    echo $l $i
    i=$(expr $i + 1)
  done > "$lang_map_file"

  mkdir -p "$exp_dir/results"

  if [ "$mode" = full ]; then
    echo "The classifier will be trained..."
    classifier_dir="$exp_dir/classifier"
  else
    echo "A trained classifier will be taken from the '${nnet_exp_dir}' experiment..."
    if [ -z ${nnet_exp_dir+x} ]; then
      echo "The nnet_exp_dir variable has to be set!"
      exit 1
    else
      classifier_dir="$nnet_exp_dir/exp/classifier"
      mkdir -p "$exp_dir/classifier"
    fi
  fi

  if [ "$mode" = full ]; then
    mkdir -p "$classifier_dir"

    # Training the log reg model
    ./local/logistic_regression_train.sh \
      --prior-scale 0.70 \
      --conf conf/logistic-regression.conf \
      --train-dir "$exp_dir/xvectors_enroll" \
      --model-dir "$classifier_dir" \
      --train-utt2lang "$exp_dir/xvectors_enroll/utt2lang" \
      --eval-utt2lang "$exp_dir/xvectors_eval/utt2lang" \
      --languages "$lang_map_file" \
      &> "$exp_dir/classifier/logistic-regression-train.log"
      
    # Classifying eval set samples
    ./local/logistic_regression_score.sh \
      --languages "$lang_map_file" \
      --model-dir "$classifier_dir" \
      --test-dir "$exp_dir/xvectors_eval" \
      --classification-file "$exp_dir/results/classification-eval" \
      &> "$exp_dir/classifier/logistic-regression-score-eval.log"
  fi

  if [ "$use_test_set" = true ]; then
    # Classifying test set samples
    ./local/logistic_regression_score.sh \
      --languages "$lang_map_file" \
      --model-dir "$classifier_dir" \
      --test-dir "$exp_dir/xvectors_test" \
      --classification-file "$exp_dir/results/classification-test" \
      &> "$exp_dir/classifier/logistic-regression-score-test.log"
  fi

  echo "Finished stage 8."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Calculating results from the raw scores.
# Runtime: < 10s
if [ $stage -eq 9 ]; then
  echo "#### STAGE 9: Calculating results. ####"
  if [ "$mode" = full ]; then
    ./local/compute_results.py \
      --classification-file "$exp_dir/results/classification-eval" \
      --output-file "$exp_dir/results/results-eval" \
      --conf-mtrx-file "$exp_dir/results/conf_matrix-eval.csv" \
      --language-list "$GP_LANGUAGES" \
      &> "$exp_dir/results/compute_results-eval.log"
  fi

  if [ "$use_test_set" = true ]; then
    ./local/compute_results.py \
      --classification-file "$exp_dir/results/classification-test" \
      --output-file "$exp_dir/results/results-test" \
      --conf-mtrx-file "$exp_dir/results/conf_matrix-test.csv" \
      --language-list "$GP_LANGUAGES" \
      &> "$exp_dir/results/compute_results-test.log"
  fi
  
  echo "Finished stage 9."
fi
