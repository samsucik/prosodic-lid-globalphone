#!/bin/bash

# Note: This file is based on make_mfcc_pitch.sh

# Begin configuration section.
nj=1
cmd=run.pl
paste_length_tolerance=2
compress=true
write_utt2num_frames=false  # if true writes utt2num_frames
feature_name=combined_features
# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
   echo "Usage: $0 [options] <data-dir1> <data-dir2> <output-dir> [<log-dir>]";
   echo "e.g.: $0 ~/mfcc/train ~/pitch/train ~/mfcc_pitch/train ~/mfcc_pitch/train/log"
   echo "Note: <log-dir> defaults to <output-dir>/log"
   echo "Options: "
   echo "  --feature-name STR                                   # name of the combined feature"
   echo "  --paste-length-tolerance   <tolerance>               # length tolerance passed to paste-feats"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>)     # how to run jobs"
   exit 1;
fi

in_dir1=$1
in_dir2=$2
out_dir=$3

if [ $# -ge 4 ]; then
  logdir=$4
else
  logdir=$out_dir/log
fi

out_dir=`perl -e '($out_dir,$pwd)= @ARGV; if($out_dir!~m:^/:) { $out_dir = "$pwd/$out_dir"; } print $out_dir; ' $out_dir ${PWD}`
in_dir1=`perl -e '($in_dir,$pwd)= @ARGV; if($in_dir!~m:^/:) { $in_dir = "$pwd/$in_dir"; } print $in_dir; ' $in_dir1 ${PWD}`
in_dir2=`perl -e '($in_dir,$pwd)= @ARGV; if($in_dir!~m:^/:) { $in_dir = "$pwd/$in_dir"; } print $in_dir; ' $in_dir2 ${PWD}`

# use "name" as part of name of the archive.
name=`basename $out_dir`

mkdir -p $out_dir || exit 1;
mkdir -p $logdir || exit 1;

scp1=$in_dir1/feats.scp
scp2=$in_dir2/feats.scp
required="$scp1 $scp2"

for f in $required; do
  if [ ! -f $f ]; then
    echo "combine_feats.sh: no such file $f"
    exit 1;
  fi
done
utils/validate_data_dir.sh --no-text --no-feats $in_dir1 || exit 1;
utils/validate_data_dir.sh --no-text --no-feats $in_dir2 || exit 1;

feats1="scp:$scp1"
feats1="scp:$scp2"

$cmd JOB=1:$nj $logdir/${feature_name}_${name}.JOB.log \
  paste-feats --length-tolerance=$paste_length_tolerance scp:$scp1 scp:$scp2 ark:- \| \
  copy-feats --compress=$compress $write_num_frames_opt ark:- \
    ark,scp:$out_dir/${feature_name}_${name}.JOB.ark,$out_dir/${feature_name}_${name}.JOB.scp \
    || exit 1;


if [ -f $logdir/.error.$name ]; then
  echo "Error combining ${feature_name} features for $name:"
  tail $logdir/${feature_name}_${name}.1.log
  exit 1;
fi

# concatenate the .scp files together.
for n in $(seq $nj); do
  cat $out_dir/${feature_name}_${name}.$n.scp || exit 1;   
done > $out_dir/feats.scp

for file in segments lang2utt spk2utt utt2lang utt2len utt2spk; do
  cp $in_dir1/$file $out_dir/
done

nf=`cat $out_dir/feats.scp | wc -l`
nu=`cat $out_dir/utt2spk | wc -l`
if [ $nf -ne $nu ]; then
  echo "It seems not all of the feature files were successfully processed ($nf != $nu);"
  echo "consider using utils/fix_data_dir.sh $out_dir"
fi

if [ $nf -lt $[$nu - ($nu/20)] ]; then
  echo "Less than 95% the features were successfully generated.  Probably a serious error."
  exit 1;
fi

echo "Succeeded combining ${feature_name} features for $name"
