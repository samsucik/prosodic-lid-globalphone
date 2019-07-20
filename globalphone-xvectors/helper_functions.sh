#!/bin/bash -u

# Copyright 2019 Sam Sucik
# 
# Apache 2.0

whichMachine() {
	# Sam's laptop
	if [[ `echo ~` = "/home/samo" ]]; then
		echo "sam"
	# Sam's DICE account
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/s15/s1513472* ]]; then
		echo "dice_sam"
	# a different DICE account
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/* ]]; then
		echo "dice_other"
	# MSc teaching cluster
	elif [ -s /disk/scratch ]; then
		# head node
		if [[ "$(hostname)" == landonia* ]]; then 
			echo "cluster_worker"
		# worker node
		else
			echo "cluster_head"
		fi
	else
		echo "unrecognised_machine"
	fi
}
