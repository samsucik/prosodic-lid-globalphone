#!/bin/bash -u

# Forked from egs/gp/s5/cmd.sh
# Author: Sam Sucik

source ./helper_functions.sh

# To run locally, use:
if [[ $(whichMachine) = "sam" ]] || [[ $(whichMachine) = "dice"* ]]; then
	echo "Running locally."
	export preprocess_cmd=run.pl
	export train_cmd=run.pl
	export extract_cmd=run.pl
elif [[ $(whichMachine) == cluster* ]]; then
	echo "Running on the cluster."
	export preprocess_cmd=run.pl
	export train_cmd=slurm.pl
	export extract_cmd=slurm.pl
else
	echo "Running on an unrecognised machine."
fi
