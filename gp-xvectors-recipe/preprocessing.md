# Preprocessing

## VAD
`local/compute_vad_decision.sh` sometimes doesn't produce entries for all utterances from `feats.scp` (because of `compute-vad` throwing: "Empty feature matrix for utterance XY"). And using `fix_data_dir.sh` doesn't address the problem of some utterances being in `feats.scp` but not in `vad.scp`.

Luckily, `select-voiced-frames` -- used in `prepare_feats_for_egs.sh` or in `extract_xvectors.sh` -- processes all utterances from the rspecifier (`feats.scp`) which also have entries in the vad-specifier (`vad.scp`), effectively throwing away utterances for which VAD couldn't be computed.

## Short utterances
I remove all utts < 0.1s. Before doing this, it was (for MFCC features on the train set):
```
129207 utts processed
91169 after removing short (< 5s) utts
```
and, for Kaldi pitch features:
```
123332 utts processed
86713 after removing short (< 5s) utts
```
After filtering out all utts < 0.1s, in the train set (both MFCC and pitch) is left:
```
129108 utts processed
91100 after removing short (< 5s) utts (MFCC)
91094 after removing short (< 5s) utts (pitch)
```