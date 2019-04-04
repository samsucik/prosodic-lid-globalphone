#!/bin/bash -u

# Copyright 2019 Sam Sucik
# 
# Apache 2.0

source path.sh

f=LDC93S6A
dir=sample-feats

feats_header="pov,pitch,delta-pitch,raw-log-pitch,energy,vad"
pitch_config=conf/kaldi_pitch.conf
pitch_postprocess_config=conf/kaldi_pitch_process.conf
energy_config=conf/mfcc_energy.conf
vad_config=conf/vad.conf
mfcc_config=conf/mfcc.conf

echo "$f ${f}.wav" > $dir/wav_${f}.scp

pitch="compute-kaldi-pitch-feats --verbose=0 --config=$pitch_config scp:$dir/wav_${f}.scp ark:- | \
	process-kaldi-pitch-feats --verbose=0 --config=$pitch_postprocess_config ark:- ark:- |"

energy="compute-mfcc-feats --verbose=0 --config=$energy_config scp:$dir/wav_${f}.scp ark:- |"

vad="compute-mfcc-feats --verbose=0 --config=$mfcc_config scp:$dir/wav_${f}.scp ark:- | \
	compute-vad --verbose=0 --config=$vad_config ark:- ark:- | \
	copy-vector --verbose=0 ark:- ark,t:- | sed -E 's/\s+([0-1])/\n  \1/g' |"

paste-feats --verbose=0 ark:"$pitch" ark:"$energy" ark:"$vad" ark:- | \
	copy-feats --verbose=0 ark:- ark,t:- | \
	tail -n +2 | sed -E "s/^\s+//g" | sed -E "s/[^-0-9. ]//g" | sed -E "s/\s+([-0-9])/,\1/g" > $dir/feats_${f}

sed -i "1s/^/${feats_header}\n/" $dir/feats_${f}
