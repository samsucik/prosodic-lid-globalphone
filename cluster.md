# How to use the UoE MSc GPU cluster
Original docs [here](http://computing.help.inf.ed.ac.uk/teaching-cluster).


## Basics
SSH into one of the head nodes, i.e. `mlp`, `mlp1` or `mlp2`.
Use `sinfo` to check available nodes.

To change into a worker node, use `srun` like so:
```
srun --nodelist=landonia04 --pty bash
```

## Networking
Only head nodes have internet access, worker nodes do not.


## Moving files
AFS home directories can be accessed from head nodes but **not** from worker nodes.

Copy things from AFS homedir to cluster homedir first (whilst in a head node), then to worker nodes (scratch disks).


## Scratch disk
This is **not** shared across nodes and can be accessed as `/disk/scratch` on every machine.


## Setting up the environment (any node)
1. Run `install_conda.sh` to ensure that Conda is installed and that the `lid` environment exists
1. Run `source ~/.bashrc; conda activate lid`
1. Install Kaldi using `install_kaldi.sh`


## Running jobs
Use `sbatch` to submit a job to slurm _from a head node_. See [here](https://slurm.schedmd.com/sbatch.html) for complete docs.

Simple example:
```
sbatch \
	--nodelist=landonia[04-08] \
	--gres=gpu:2 \
	--job-name=LID \
	--mail-type=END \
	--mail-user=sucik.samo@gmail.com \
	--open-mode=append \
	--output=cluster-exploration.out \
	explore.sh
```

To check the job queue use `squeue`.


## Workflow
1. Ensure environment is activated and everything is installed
1. Move data to head node
1. Run script from head node

## Longjobbing
```
(echo 'YourDicePassword' | nohup longjob -28day -c './run.sh --exp-config=conf/exp_default.conf --stage=1' &> nohup-baseline.out ) &
```