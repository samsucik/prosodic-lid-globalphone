#!/bin/bash -u

# Copyright 2019 Sam Sucik
# 
# Apache 2.0

PROG=`basename $0`;
usage="Usage: $PROG <arguments>\n
Scrape the information on articles read by every speaker and save it in the output directory.\n
e.g.: $PROG --lang-map=conf/lang_codes.txt --corpus-dir=/disk/scratch/lid/global_phone --output-dir=speakers\n\n
Required arguments:\n
  --lang-map=FILE\tThe file providing the mapping from language code to full names.\n
  --corpus-dir=DIR\tDirectory for the GlobalPhone corpus\n
  --output-dir=DIR\tDirectory where language-specific speaker-articles lists will be saved\n
";

function error_exit () {
  echo -e "$@" >&2; exit 1;
}

if [ $# -lt 3 ]; then
  error_exit $usage;
fi

function read_dirname () {
  local dir_name=`expr "X$1" : '[^=]*=\(.*\)'`;
  [ -d "$dir_name" ] || mkdir -p "$dir_name" || error_exit "Directory '$dir_name' not found";
  local retval=`cd $dir_name 2>/dev/null && pwd || exit 1`
  echo $retval
}

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --corpus-dir=*)
  GP_CORPUS=`read_dirname $1`; shift ;;
  --lang-map=*)
  LANGMAP=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --output-dir=*)
  OUT_DIR=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done


mkdir -p $OUT_DIR

for L in AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU VN WU; do
	echo "### $L ###"

	full_name=`awk '/'$L'/ {print $2}' $LANGMAP`;
	spk_path=$full_name
	if [ "$full_name" == "Chinese-Shanghai" ]; then
		spk_path=$full_name/Wu
	fi
	spk_path=$GP_CORPUS/$spk_path/spk
	
	# if spk data not present
	if [ ! -s $spk_path ] || [ -z "$(ls -A $spk_path)" ]; then
		continue
	fi
	
	for spk_file in $spk_path/*.spk; do
		spk_num=$(echo "$spk_file" | sed -En "s/.*[A-Z]+([0-9]+)\..*/\1/p")
		articles=$(cat $spk_file | grep -E ';ARTICLE READORDER:' | \
				   sed -En "s/(;ARTICLE READORDER:|\n)//p" | \
                                   tr -d '\012\015' | awk '{$1=$1};1')
		
		if [[ -z "$articles" || "$articles" == "Unknown"* ]]; then
			# no articles for spk
			continue
		else
			echo "${spk_num}|${articles}" >> $OUT_DIR/${L}_spk_metadata
		fi
	done
done
