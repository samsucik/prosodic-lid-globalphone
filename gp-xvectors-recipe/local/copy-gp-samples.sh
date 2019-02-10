#!/bin/bash -u

# Copies samples (N speakers per language) from /group/corpora/public/...
# to specified directory. Skips languages Chinese-Shanghai, Tamil and Hausa
# because the file structure of these is not the standard one (as for other
# languages).

num_speakers_per_language=3

if [ $# != 2 ]; then
  echo "Usage: $0 <target-dir> <#speakers-per-language>"
  echo " e.g.: $0 ~/global_phone"
  exit 0
else
  target_dir=$1/
  num_speakers_per_language=$2
fi

gpPath=/group/corpora/public/global_phone
arr=($(find "$gpPath" -maxdepth 1 -mindepth 1 -name "[[:upper:]]*" -type d -printf '%f\n'))
toExclude=( Dictionaries )

for d in "${arr[@]/$toExclude}" ; do
    if [[ "$d" = "" ]]; then
        echo "Skipping invalid language"
        continue
    fi
    echo "Copying language: ${d}"
    mkdir -p $target_dir$d/
    mkdir -p $target_dir$d/adc/
    mkdir -p $target_dir$d/spk/
    mkdir -p $target_dir$d/trl/
    sampleSpeakers=($(ls "${gpPath}/${d}/adc/" | sort -n | head -n $num_speakers_per_language))
    echo "  Copying speakers: ${sampleSpeakers[*]}"

    for speakerDir in "${sampleSpeakers[@]}"; do
        speakerFile=$(ls "${gpPath}/${d}/spk/" | grep ".*$speakerDir.*" | sort -n | head -1)
        transcriptFile=$(ls "${gpPath}/${d}/trl/" | grep ".*$speakerDir.*" | sort -n | head -1)
        echo "      Copying audio for speaker: ${speakerDir}"
        echo "      Copying speaker file: ${speakerFile}"
        echo "      Copying transcript file: ${transcriptFile}"
        cp -n -R $gpPath/$d/adc/$speakerDir $target_dir$d/adc
        cp -n $gpPath/$d/spk/$speakerFile $target_dir$d/spk/
        cp -n $gpPath/$d/trl/$transcriptFile $target_dir$d/trl/
    done
done

echo "Now copying the dictionaries"
rsync -av --exclude='*.pdf' --exclude='*.dict' --exclude='*.trl' --no-perms --omit-dir-times $gpPath/Dictionaries $target_dir
