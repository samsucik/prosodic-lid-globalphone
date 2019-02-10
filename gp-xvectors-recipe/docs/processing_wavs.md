# Working with SHN and WAV files

## Turning SHNs into WAVs
Run the first stage of `run.sh` like so:
```bash
./run.sh --stage=47
```
This will store ALL .wav files (disregarding your train/eval/... sets). Stage 48 then creates lists referring to WAVs specific to your train/eval sets.

## Analysing bad utterances
Some SHNs are bad (corrupt). To see them, go to the WAV root (the directory that contains the folders like AR, BG, etc) and run:
```bash
for L in AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU VN WU; do
	echo "Bad SHNs for language $L"
	pushd $L/lists
	cat shn.list | grep -ohE '[A-Za-z0-9_]+\.adc' | grep -ohE '[0-9_]+' | sort > shns
	cat wav.list | grep -ohE '[A-Za-z0-9_]+\.wav' | grep -ohE '[0-9_]+' | sort > wavs
	comm -23 <(sort shns) <(sort wavs) > bad_shns.list
	rm shns wavs
	cat bad_shns.list
	popd
done
```

## Moving WAVs around
Normally, all WAVs are accessible at `/mnt/mscteach_home/s1513472/lid/wav/` on the cluster. If you need to move them around, feel free to do so, but you'll need to change the absolute paths in the `wav.scp` (and possibly some other files). For example, after moving the WAV data from the scratch disk to ~/lid/wav, run this:
```bash
for L in AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU VN WU; do
	echo "Doing $L"
	pushd $L/lists
	cp wav.scp wav.scp.bak
	cat wav.scp.bak | sed 's?/home/s1513472?/mnt/mscteach_home/s1513472?g' > wav.scp
	popd
done
```
