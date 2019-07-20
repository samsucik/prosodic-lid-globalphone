#!/bin/bash

# Adapted from steps/make_mfcc.sh by Sam Sucik
# Copyright 2019 Sam Sucik
# 
# Apache 2.0

# Begin configuration section.
nj=4
cmd=run.pl
sdc_config=conf/sdc.conf
compress=true
write_utt2num_frames=false  # if true writes utt2num_frames
# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
   echo "Usage: $0 [options] <data-dir> [<log-dir> [<sdc-dir>] ]";
   echo "e.g.: $0 data/train exp/make_sdc/train sdc"
   echo "Note: <log-dir> defaults to <data-dir>/log, and <sdc_dir> defaults to <data-dir>/data"
   echo "Options: "
   echo "  --sdc-config <config-file>                       # config passed to add-deltas-sdc "
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --write-utt2num-frames <true|false>              # If true, write utt2num_frames file."
   exit 1;
fi

data_in=$1
if [ $# -ge 2 ]; then
  logdir=$2
else
  logdir=$data_in/log
fi
if [ $# -ge 3 ]; then
  sdc_dir=$3
else
  sdc_dir=$data_in/data
fi

# make $sdc_dir an absolute pathname.
sdc_dir=`perl -e '($dir,$pwd)= @ARGV; if($dir!~m:^/:) { $dir = "$pwd/$dir"; } print $dir; ' $sdc_dir ${PWD}`

# use "name" as part of name of the archive.
name=`basename $data_in`

mkdir -p $sdc_dir || exit 1;
mkdir -p $logdir || exit 1;

if [ -f $data_in/feats.scp ]; then
  mkdir -p $data_in/.backup
  echo "$0: moving $data_in/feats.scp to $data_in/.backup"
  cp $data_in/feats.scp $data_in/.backup
fi

scp=$data_in/.backup/feats.scp
required="$scp $sdc_config"

for f in $required; do
  if [ ! -f $f ]; then
    echo "make_sdc.sh: no such file $f"
    exit 1;
  fi
done
utils/validate_data_dir.sh --no-text --no-feats $data_in || exit 1;

if $write_utt2num_frames; then
  write_num_frames_opt="--write-num-frames=ark,t:$logdir/utt2num_frames.JOB"
else
  write_num_frames_opt=
fi

sdata_in=$data_in/split$nj;
utils/split_data.sh $data_in $nj || exit 1;

$cmd JOB=1:$nj $logdir/make_sdc_${name}.JOB.log \
  add-deltas-sdc --config=$sdc_config scp:${sdata_in}/JOB/feats.scp ark:- \| \
  copy-feats $write_num_frames_opt --compress=$compress ark:- \
    ark,scp:$sdc_dir/sdc_${name}.JOB.ark,$sdc_dir/sdc_${name}.JOB.scp \
    || exit 1;

if [ -f $logdir/.error.$name ]; then
  echo "Error producing SDC features for $name:"
  tail $logdir/make_sdc_${name}.1.log
  exit 1;
fi

# concatenate the .scp files together.
for n in $(seq $nj); do
  cat $sdc_dir/sdc_${name}.$n.scp || exit 1;
done > $data_in/feats.scp || exit 1

if $write_utt2num_frames; then
  for n in $(seq $nj); do
    cat $logdir/utt2num_frames.$n || exit 1;
  done > $data_in/utt2num_frames || exit 1
  rm $logdir/utt2num_frames.*
fi

# rm $logdir/wav_${name}.*.scp  $logdir/segments.* 2>/dev/null

nf=`cat $data_in/feats.scp | wc -l`
nu=`cat $data_in/utt2spk | wc -l`
if [ $nf -ne $nu ]; then
  echo "It seems not all of the feature files were successfully processed ($nf != $nu);"
  echo "consider using utils/fix_data_dir.sh $data_in"
fi

if [ $nf -lt $[$nu - ($nu/20)] ]; then
  echo "Less than 95% the features were successfully generated.  Probably a serious error."
  exit 1;
fi

echo "Succeeded creating SDC features for $name"
