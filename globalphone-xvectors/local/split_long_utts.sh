#!/bin/bash -u

# Adapted from egs/lre07/v2/local/split_long_utts.sh
# Copyright 2019 Sam Sucik
# 
# Apache 2.0

max_utt_len=60 # 60 seconds.
stage=1
cleanup=true

. utils/parse_options.sh

if [ $# -ne 2 ]; then
  echo "Usage: $0 [options] <in-data-dir> <out-data-dir>"
  echo "e.g.: $0 --max-utt-len 120 data/train data/train_split"
  echo "This script splits up long utterances into smaller pieces."
  echo "It assumes the wav.scp has a certain form, with .wav"
  echo "files in it (so the script is not completely general)."
  exit 1;
fi

in_dir=$1
out_dir=$2

for f in $in_dir/{utt2spk,spk2utt,wav.scp,utt2lang}; do
  if [ ! -f $f ]; then
    echo "$0: expected input file $f to exist";
    exit 1;
  fi
done

if [ $stage -le 1 ]; then
  mkdir -p $out_dir

  if [ "$in_dir" == "$out_dir" ]; then
    echo "Input and output directory are the same one. Backing up original utt2spk," \
    "spk2utt, utt2lang, lang2utt, utt2len and wav.scp files (with the '.unsplit' suffix)."
    for f in utt2spk spk2utt utt2lang lang2utt wav.scp; do
      # Do copying that doesn't fail if the file doesn't exist
      cp $in_dir/$f $in_dir/${f}.unsplit 2>/dev/null || :
    done
  fi

  # Create, in a pipe, a file with lines
  # <utt-id> <length> <speaker-id> <language-id>
  # and pipe it into a perl script that outputs the segments file.
  awk '{print $2}' $in_dir/utt2spk | paste $in_dir/utt2len -  | \
   paste -  <(awk '{print $2}' $in_dir/utt2lang) | perl -e '
  ($max_utt_len, $out_dir) = @ARGV;
  open(UTT2SPK, ">$out_dir/utt2spk") || die "opening utt2spk file $out_dir/utt2spk";
  open(SEGMENTS, ">$out_dir/segments") || die "opening segments file $out_dir/segments";
  open(UTT2LANG, ">$out_dir/utt2lang") || die "opening segments file $out_dir/utt2lang";
  while(<STDIN>) {
    ($utt, $len, $speaker, $language) = split(" ", $_);
    defined $speaker || die "Bad line $_";
    $reco = $utt; # old utt-id becomes recording-id.
    if ($len <= $max_utt_len) {
      print SEGMENTS "${utt}-1 ${utt} 0 $len\n";
      print UTT2SPK "${utt}-1 $speaker\n";
      print UTT2LANG "${utt}-1 $language\n";
    } else {
      # We will now allow split length to exceed max_utt_len.
      $num_split = int(($len + 0.999*$max_utt_len) / $max_utt_len);
      $num_split >= 1 || die;
      $split_len = $len / $num_split;
      for ($n = 1; $n <= $num_split; $n++) {
         $n_text = $n; # this will help remain in string-sorted order
         if ($num_split >= 10 && $n < 10) { $n_text = "0$n_text"; }
         if ($num_split >= 100 && $n < 100) { $n_text = "00$n_text"; }
         $t_start = $split_len * ($n - 1); $t_end = $split_len * $n;
         print SEGMENTS "${utt}-$n_text ${utt} $t_start $t_end\n";
         print UTT2SPK "${utt}-$n_text $speaker\n";
         print UTT2LANG "${utt}-$n_text $language\n";
      }
    }
  }
  close(SEGMENTS)||die; close(UTT2SPK)||die; close(UTT2LANG)||die; ' $max_utt_len $out_dir
fi

if [ "$in_dir" != "$out_dir" ]; then
  cp $in_dir/wav.scp $out_dir/
fi

utils/utt2spk_to_spk2utt.pl $out_dir/utt2spk > $out_dir/spk2utt
./local/utt2lang_to_lang2utt.pl $out_dir/utt2lang > $out_dir/lang2utt

utils/validate_data_dir.sh --no-text --no-feats $out_dir || exit 1;

exit 0;
