#!/bin/bash

# Copyright     2017  David Snyder
#               2017  Johns Hopkins University (Author: Daniel Povey)
#               2017  Johns Hopkins University (Author: Daniel Garcia Romero)
# Apache 2.0.

# This script extracts embeddings (called "xvectors" here) from a set of
# utterances, given features and a trained DNN.  The purpose of this script
# is analogous to sid/extract_ivectors.sh: it creates archives of
# vectors that are used in speaker recognition.  Like ivectors, xvectors can
# be used in PLDA or a similar backend for scoring.

# Begin configuration section.
nj=30
cmd="run.pl"

cache_capacity=64 # Cache capacity for x-vector extractor
chunk_size=-1     # The chunk size over which the embedding is extracted.
                  # If left unspecified, it uses the max_chunk_size in the nnet
                  # directory.
use_gpu=false
stage=0
remove_nonspeech=false
min_len=100

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# != 3 ]; then
  echo "Usage: $0 <nnet-dir> <data> <xvector-dir>"
  echo " e.g.: $0 exp/xvector_nnet data/train exp/xvectors_train"
  echo "main options (for others, see top of script file)"
  echo "  --config <config-file>                           # config containing options"
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  echo "  --use-gpu <bool|false>                           # If true, use GPU."
  echo "  --nj <n|30>                                      # Number of jobs"
  echo "  --stage <stage|0>                                # To control partial reruns"
  echo "  --cache-capacity <n|64>                          # To speed-up xvector extraction"
  echo "  --chunk-size <n|-1>                              # If provided, extracts embeddings with specified"
  echo "                                                   # chunk size, and averages to produce final embedding"
  echo "  --min-len <n|100>                                # Minimum speech segment length (in frames, before VAD) to consider"
  echo "  --remove-nonspeech <true|false>                  # If true, removes non-speech frames (requires vad.scp)"
fi

nnet_dir=$1
feat_dir=$2
xvector_dir=$3

for f in $nnet_dir/final.raw $nnet_dir/min_chunk_size $nnet_dir/max_chunk_size $feat_dir/feats.scp; do
  [ ! -f $f ] && echo "No such file $f" && exit 1;
done

if [ "$remove_nonspeech" = true ]; then
  [ ! -f $feat_dir/vad.scp ] && echo "$0: No such file $feat_dir/vad.scp" && exit 1;
fi

min_chunk_size=`cat $nnet_dir/min_chunk_size 2>/dev/null`
max_chunk_size=`cat $nnet_dir/max_chunk_size 2>/dev/null`

nnet=$nnet_dir/final.raw
if [ -f $nnet_dir/extract.config ] ; then
  echo "$0: using $nnet_dir/extract.config to extract xvectors"
  nnet="nnet3-copy --nnet-config=$nnet_dir/extract.config $nnet_dir/final.raw - |"
fi

if [ $chunk_size -le 0 ]; then
  chunk_size=$max_chunk_size
fi

if [ $max_chunk_size -lt $chunk_size ]; then
  echo "$0: specified chunk size of $chunk_size is larger than the maximum chunk size, $max_chunk_size" && exit 1;
fi

mkdir -p $xvector_dir/log


# Copying list files into x-vector dir (so we don't mess with orignal files)
for f in spk2utt utt2lang lang2utt vad.scp; do
  cp $feat_dir/$f $xvector_dir/$f
done

echo "Removing features with less than ${min_len} frames..."
awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' $feat_dir/utt2num_frames > $xvector_dir/utt2num_frames
utils/filter_scp.pl $xvector_dir/utt2num_frames $feat_dir/feats.scp > $xvector_dir/feats.scp
utils/fix_data_dir.sh $xvector_dir

utils/split_data.sh $xvector_dir $nj
echo "$0: extracting xvectors for $feat_dir (taking lists of utts from ${xvector_dir})"
sdata=$xvector_dir/split$nj/JOB

# Set up the features
if [ "$remove_nonspeech" = true ]; then
  feat="ark:apply-cmvn-sliding --norm-vars=false --center=true --cmn-window=300 scp:${sdata}/feats.scp ark:- | select-voiced-frames ark:- scp,s,cs:${sdata}/vad.scp ark:- |"
else
  feat="ark:apply-cmvn-sliding --norm-vars=false --center=true --cmn-window=300 scp:${sdata}/feats.scp ark:- |"
fi

if [ $stage -le 0 ]; then
  echo "$0: extracting xvectors from nnet"
  if $use_gpu; then
    for g in $(seq $nj); do
      $cmd --gpu 1 ${xvector_dir}/log/extract.$g.log \
        nnet3-xvector-compute --use-gpu=yes --min-chunk-size=$min_chunk_size --chunk-size=$chunk_size --cache-capacity=${cache_capacity} \
        "$nnet" "`echo $feat | sed s/JOB/$g/g`" ark,scp:${xvector_dir}/xvector.$g.ark,${xvector_dir}/xvector.$g.scp || exit 1 &
    done
    wait
  else
    $cmd JOB=1:$nj ${xvector_dir}/log/extract.JOB.log \
      nnet3-xvector-compute --use-gpu=no --min-chunk-size=$min_chunk_size --chunk-size=$chunk_size --cache-capacity=${cache_capacity} \
      "$nnet" "$feat" ark,scp:${xvector_dir}/xvector.JOB.ark,${xvector_dir}/xvector.JOB.scp || exit 1;
  fi
fi

if [ $stage -le 1 ]; then
  echo "$0: combining xvectors across jobs"
  for j in $(seq $nj); do cat $xvector_dir/xvector.$j.scp; done >$xvector_dir/xvector.scp || exit 1;
fi

if [ $stage -le 2 ]; then
  # Average the utterance-level xvectors to get language-level xvectors.
  echo "$0: computing mean of xvectors for each language"
  $cmd $xvector_dir/log/language_mean.log \
    ivector-mean ark:$xvector_dir/lang2utt scp:$xvector_dir/xvector.scp \
    ark,scp:$xvector_dir/lang_xvector.ark,$xvector_dir/lang_xvector.scp ark,t:$xvector_dir/num_utts.ark || exit 1;
fi
