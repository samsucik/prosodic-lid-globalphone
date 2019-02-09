# Preprocessing

## VAD
`local/compute_vad_decision.sh` sometimes doesn't produce entries for all utterances from `feats.scp` (because of `compute-vad` throwing: "Empty feature matrix for utterance XY"). And using `fix_data_dir.sh` doesn't address the problem of some utterances being in `feats.scp` but not in `vad.scp`.

Luckily, `select-voiced-frames` processes all utterances from the rspecifier (`feats.scp`) which also have entries in the vad-specifier (`vad.scp`), effectively throwing away utterances for which VAD couldn't be computed.
