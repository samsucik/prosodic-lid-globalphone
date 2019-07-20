# Various pieces of practical advice (tailored for UoE people)

## Copying GlobalPhone

Use rsync. First, on DICE, copy from NFS (`/group/corpora/public/global_phone`) to home directory:
```bash
rsync -av --no-perms --omit-dir-times /afs/inf.ed.ac.uk/group/corpora/public/global_phone/Ukrainian/ ~/lid/global_phone/Ukrainian
```

Then, on cluster head node, copy from DICE home (AFS) to cluster node scratch disk:
```bash
rsync -av --no-perms --omit-dir-times /afs/inf.ed.ac.uk/user/s15/s1513472/lid/global_phone/Ukrainian/ /disk/scratch/lid/global_phone/Ukrainian
```

## Backing up models and results to DICE

In the cluster, run:
```bash
pushd ~/lid
backup_dir=/afs/inf.ed.ac.uk/user/s15/s1513472/lid-backup
for d in ./*; do
  echo "Backing up $d ..."
  # rm -rf $backup_dir/$d
  mkdir -p $backup_dir/$d

  rsync -av --exclude='q/' --exclude='*.log' --exclude='.backup/' --exclude='log/' \
        --exclude='split*/' --exclude='xvector.*.scp' --progress $d/exp $backup_dir/$d
  
  rsync -av $d/nnet/final.raw $d/nnet/extract.config $d/nnet/accuracy.output.report $backup_dir/$d/
done
```

## Gathering results from experiment directories
```bash
results_dir=~/prosodic-lid-globalphone/globalphone-xvectors/results
pushd ~/lid
for d in *; do
  echo $d
  rsync --no-R --no-implied-dirs $d/exp/results/conf_matrix-eval.csv $results_dir/${d}_conf_matrix-eval.csv
  rsync --no-R --no-implied-dirs $d/exp/results/conf_matrix-test.csv $results_dir/${d}_conf_matrix-test.csv

  rsync --no-R --no-implied-dirs $d/exp/results/results-eval $results_dir/${d}_results-eval
  rsync --no-R --no-implied-dirs $d/exp/results/results-test $results_dir/${d}_results-test

  rsync --no-R --no-implied-dirs $d/nnet/accuracy.output.report $results_dir/${d}_accuracy.output.report
done

pushd ~/prosodic-lid-globalphone/globalphone-xvectors/exp
for d in *; do
  rsync --no-R --no-implied-dirs $d/results/conf_matrix-eval.csv $results_dir/${d}_conf_matrix-eval.csv
  rsync --no-R --no-implied-dirs $d/results/conf_matrix-test.csv $results_dir/${d}_conf_matrix-test.csv

  rsync --no-R --no-implied-dirs $d/results/results-eval $results_dir/${d}_results-eval
  rsync --no-R --no-implied-dirs $d/results/results-test $results_dir/${d}_results-test
done
popd; popd
```
