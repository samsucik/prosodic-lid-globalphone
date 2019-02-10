# Computing features

## VAD
`local/compute_vad_decision.sh` sometimes doesn't produce entries for all utterances from `feats.scp` (because of `compute-vad` throwing: "Empty feature matrix for utterance XY"). And using `fix_data_dir.sh` doesn't address the problem of some utterances being in `feats.scp` but not in `vad.scp`.

Luckily, `select-voiced-frames` -- used in `prepare_feats_for_egs.sh` or in `extract_xvectors.sh` -- processes all utterances from the rspecifier (`feats.scp`) which also have entries in the vad-specifier (`vad.scp`), effectively throwing away utterances for which VAD couldn't be computed.

## Pitch
`compute-and-process-kaldi-pitch-feats` struggles with utts that are very short (probably, the files are plain corrupt or they don't have the minimum number of frames for pitch deltas). This happens a lot especially for Portuguese utterances and seems to be a residual after the unsuccessful conversion from SHN to WAV.

In the log, on first finds this warning:
```
(pitch-functions.cc:1318) No frames output in pitch extraction
```
followed by this error:
```
(pitch-functions.cc:1410) : 'src->Dim() == kRawFeatureDim && "Input feature must be pitch feature (should have dimension 2)"'
```
At this point, processing the utterances from a given SCP stops and, potentially, a lot of good utterances which follow the one corrupt one will not get processed. In this way, just 2 or 3 bad utterances were causing the Kaldi pitch feature computation to process 5875 training utterances fewer than the MFCC computation. To get rid of these corrupt utterances, I introduced minimum length filtering:

### Removing too short and corrupt utterances
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
91100 after removing short (< 5s) utts (MFCC, energy, pitch_energy)
91094 after removing short (< 5s) utts (pitch)
```