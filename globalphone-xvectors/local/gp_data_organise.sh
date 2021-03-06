#!/bin/bash -u

# Adapted from egs/gp/s5/local/gp_data_prep.sh by Sam Sucik and Paul Moore
# Copyright 2019 Sam Sucik and Paul Moore
# 
# Apache 2.0

set -o errexit

function error_exit () {
  echo -e "$@" >&2; exit 1;
}

function read_dirname () {
  local dir_name=`expr "X$1" : '[^=]*=\(.*\)'`;
  [ -d "$dir_name" ] || mkdir -p "$dir_name" || error_exit "Directory '$dir_name' not found";
  local retval=`cd $dir_name 2>/dev/null && pwd || exit 1`
  echo $retval
}

PROG=`basename $0`;
usage="Usage: $PROG <arguments>\n
Prepare train, enroll, eval and test file lists for a language.\n
e.g.: $PROG --config-dir=conf --corpus-dir=corpus --languages=\"GE PO SP\"\n\n
Required arguments:\n
  --wav-dir=DIR\tDirectory containing the raw WAV files to be used\n
  --data-dir=DIR\tDirectory in which the data partition subdirectories will be created, containing \n
    the various list files \n
  --config-dir=DIR\tDirectory containing the necessary config files\n
  --languages=STR\tSpace separated list of two letter language codes\n
";

if [ $# -lt 4 ]; then
  error_exit $usage;
fi

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --config-dir=*)
  CONFDIR=`read_dirname $1`; shift ;;
  --languages=*)
  LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --data-dir=*)
  datadir=`read_dirname $1`; shift ;;
  --wav-dir=*)
  WAVDIR=`read_dirname $1`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

# Check if the config files are in place:
pushd $CONFDIR > /dev/null
if [ -f test_spk.list ]; then
  test_list=$CONFDIR/test_spk.list
else
  echo "Test-set speaker list not found."; exit 1
fi
if [ -f eval_spk.list ]; then
  eval_list=$CONFDIR/eval_spk.list
else
  echo "Eval-set speaker list not found."; exit 1
fi
if [ -f enroll_spk.list ]; then
  enroll_list=$CONFDIR/enroll_spk.list
else
  echo "Enrollment-set speaker list not found."; exit 1
fi
if [ -f train_spk.list ]; then
  train_list=$CONFDIR/train_spk.list
fi
popd > /dev/null

[ -f path.sh ] && . ./path.sh  # Sets the PATH to contain necessary executables

# Make data folders to contain all the language files.
for x in train enroll eval test; do
  mkdir -p $datadir/${x}
done

tmpdir=$(mktemp -d /tmp/kaldi.XXXX);
trap 'rm -rf "$tmpdir"' EXIT

for L in $LANGUAGES; do
  (
  mkdir $tmpdir/$L
  grep "^$L" $test_list | cut -f2- | tr ' ' '\n' \
    | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/$L/test_spk
  grep "^$L" $eval_list | cut -f2- | tr ' ' '\n' \
    | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/$L/eval_spk
  grep "^$L" $enroll_list | cut -f2- | tr ' ' '\n' \
    | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/$L/enroll_spk
  if [ -f $CONFDIR/train_spk.list ]; then
    grep "^$L" $train_list | cut -f2- | tr ' ' '\n' \
      | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/$L/train_spk
  else
    echo "Train-set speaker list not found. Using all speakers not in eval set."
    grep -v -f $tmpdir/$L/test_spk -f $tmpdir/$L/eval_spk -f $tmpdir/$L/enroll_spk \
      $WAVDIR/$L/lists/spk > $tmpdir/$L/train_spk || \
      echo "Could not find any training set speakers; \
      are you trying to use all of them for evaluation and testing?";
  fi
  
  echo "Language - ${L}: formatting train/enroll/eval/test data."
  for x in train enroll eval test; do
    mkdir -p $datadir/$L/$x
    rm -f $datadir/$L/$x/wav.scp $datadir/$L/$x/spk2utt \
          $datadir/$L/$x/utt2spk $datadir/$L/$x/utt2len
    
    for spk in `cat $tmpdir/$L/${x}_spk`; do
      grep -h "$spk" $WAVDIR/$L/lists/wav.scp >> $datadir/$L/$x/wav.scp
      grep -h "$spk" $WAVDIR/$L/lists/spk2utt >> $datadir/$L/$x/spk2utt
      grep -h "$spk" $WAVDIR/$L/lists/utt2spk >> $datadir/$L/$x/utt2spk
      grep -h "$spk" $WAVDIR/$L/lists/utt2len >> $datadir/$L/$x/utt2len
    done

    echo "Removing short utterances (< 0.1s)"
    min_len=0.1
    mv $datadir/$L/$x/utt2len $datadir/$L/$x/utt2len.bak
    awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' $datadir/$L/$x/utt2len.bak > $datadir/$L/$x/utt2len
    utils/filter_scp.pl $datadir/$L/$x/utt2len $datadir/$L/$x/utt2spk > $datadir/$L/$x/utt2spk.new
    mv $datadir/$L/$x/utt2spk.new $datadir/$L/$x/utt2spk
    utils/fix_data_dir.sh $datadir/$L/$x
    
  done
  ) &
done
wait;
echo "Done"

# Combine data from all languages into big piles
train_dirs=()
eval_dirs=()
enroll_dirs=()
test_dirs=()

for L in $LANGUAGES; do
  train_dirs+=($datadir/$L/train)
  enroll_dirs+=($datadir/$L/enroll)
  eval_dirs+=($datadir/$L/eval)
  test_dirs+=($datadir/$L/test)
done

echo "Combining training directories: $(echo ${train_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh --extra-files 'utt2len' $datadir/train ${train_dirs[@]}

echo "Combining enrollment directories: $(echo ${enroll_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh --extra-files 'utt2len' $datadir/enroll ${enroll_dirs[@]}

echo "Combining evaluation directories: $(echo ${eval_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh --extra-files 'utt2len' $datadir/eval ${eval_dirs[@]}

echo "Combining testing directories: $(echo ${test_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh --extra-files 'utt2len' $datadir/test ${test_dirs[@]}


# Add utt2lang and lang2utt files for the collected languages
for x in train enroll eval test; do
  sed -e 's?[0-9]*$??' $datadir/${x}/utt2spk \
  > $datadir/${x}/utt2lang

  ./local/utt2lang_to_lang2utt.pl $datadir/${x}/utt2lang \
  > $datadir/${x}/lang2utt
done

echo "Finished data preparation."
