#!/bin/bash -u

whichMachine() {
	if [[ `echo ~` = "/home/samo" ]]; then
		echo "sam"
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/s15/s1513472* ]]; then
		echo "dice_sam"
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/* ]]; then
		echo "dice_other"
	elif [ -s /disk/scratch ]; then
		if [[ "$(hostname)" == landonia* ]]; then 
			echo "cluster_worker"
		else
			echo "cluster_head"
		fi
	else
		echo "unrecognised_machine"
	fi
}
