#!/bin/bash -u

# Adapted from egs/gp/s5/path.sh by Sam Sucik and Paul Moore
# Copyright 2019 Sam Sucik and Paul Moore
# 
# Apache 2.0

# This contains the locations of the tools and data required for running
# the GlobalPhone experiments.


source ./helper_functions.sh

[ -f conf/user_specific_config.sh ] && source ./conf/user_specific_config.sh \
	|| echo "conf/user_specific_config.sh not found, create it by cloning " + \
					"conf/user_specific_config-example.sh"

export LC_ALL=C  # For expected sorting and joining behaviour

[ -d $PWD/local ] || { echo "Error: 'local' subdirectory not found."; }
[ -d $PWD/utils ] || { echo "Error: 'utils' subdirectory not found."; }
[ -d $PWD/steps ] || { echo "Error: 'steps' subdirectory not found."; }

export kaldi_local=$PWD/local
export kaldi_utils=$PWD/utils
export kaldi_steps=$PWD/steps

SCRIPTS=$kaldi_local:$kaldi_utils:$kaldi_steps
export PATH=$PATH:$SCRIPTS

# If the correct version of shorten and sox are not on the path,
# the following will be set by local/gp_check_tools.sh
SHORTEN_BIN=/home/s1513472/language-ident-from-speech/gp-xvectors-recipe/tools/shorten-3.6.1/bin
# e.g. $PWD/tools/shorten-3.6.1/bin
SOX_BIN=/home/s1513472/language-ident-from-speech/gp-xvectors-recipe/tools/sox-14.3.2/bin
# e.g. $PWD/tools/sox-14.3.2/bin
export PATH=$SHORTEN_BIN:$PATH
export PATH=$SOX_BIN:$PATH

if [[ $(whichMachine) = "sam" ]]; then
	GP_CORPUS=/afs/inf.ed.ac.uk/user/s15/s1513472/global_phone/
elif [[ $(whichMachine) = "dice_sam" ]]; then
	GP_CORPUS=~/global_phone/
	#GP_CORPUS=/group/corpora/public/global_phone
elif [[ $(whichMachine) = "dice_other" ]]; then
	GP_CORPUS=/group/corpora/public/global_phone
elif [[ $(whichMachine) == cluster* ]]; then
	GP_CORPUS=/disk/scratch/lid/global_phone
else
	echo "NOT IMPLEMENTED: setting GlobalPhone directory."
fi

if [ -z ${CONDA_DEFAULT_ENV+x} ]; then
  if [[ $(whichMachine) == cluster* ]]; then
    echo "Conda environment not activated, sourcing ~/.bashrc and activating the 'lid' env."
    source ~/.bashrc
    conda activate lid || exit
  elif [[ $(whichMachine) == dice* ]]; then
    echo "Conda environment not activated, trying to activate it."
    source activate lid || exit
  else
    echo "Conda environment not activated, trying to activate it."
    conda activate lid || exit
  fi
else
  echo "Conda environment '$CONDA_DEFAULT_ENV' active."
fi

