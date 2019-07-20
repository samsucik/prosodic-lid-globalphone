# Prosodic language identification from speech

This is the project I created for my Year 4 dissertation at the University of Edinburgh (the dissertation itself can be found [here](https://github.com/samsucik/prosodic-lid-globalphone-dissertation)).

This work explores the use of prosodic features (in addition to the standard acoustic features) for better language identification, using the recently proposed [X-vector approach](http://www.danielpovey.com/files/2018_odyssey_xvector_lid.pdf), speech data in 19 languages from the [GlobalPhone corpus](http://www.cs.cmu.edu/~tanja/GlobalPhone/index-e.html), and the [Kaldi toolkit](https://github.com/kaldi-asr/kaldi).

## Why should I care?

Basically, my results show that adding prosodic features (in particular the Kaldi pitch) greatly improves LID performance, especially when doing intermediate fusion of different feature types at the utterance embedding level (as opposed to early fusion at the speech frame level). Also, the implementation in [globalphone-xvectors/](globalphone-xvectors/) is a standard Kaldi recipe, easy to re-use for any user of Kaldi willing to further explore prosodic LID. Why not giving it a try, perhaps on a different dataset or with different prosodic features? You can also skim through my [dissertation](https://github.com/samsucik/prosodic-lid-globalphone-dissertation) first, it's public, based entirely on this repository, and its repository contains many detailed results.

## How to use it

Obviously, you should have Kaldi installed, and also have access to the GlobalPhone corpus. For training the X-vector TDNN, you might want to have some GPUs at hand. I myself was using a GPU cluster with Slurm as the job manager. Some more specific details on the kind of computing environment you will need:
- having a Conda environment named `lid`, based on this [environment file](environment.yml) and with requirements from [`requirements.txt`](requirements.txt) installed
- use Python 3, or else things can break
- as for scripts from the `egs/` directory, in particular from the `steps` and `utils` directories of `egs/wsj/s5`, feel free to ignore the version of `egs/` included in this repository and use your own, but make sure that you are on par or ahead of [this Kaldi pull request](https://github.com/kaldi-asr/kaldi/pull/2925) (it fixed a few instances in which things were breaking for Python 3).

To actually make it all run:
1. Start by creating a user-specific config in `conf/user_specific_config.sh` by cloning and changing [`conf/user_specific_config-example.sh`](globalphone-xvectors/conf/user_specific_config-example.sh).
1. Skim through [`run.sh`](globalphone-xvectors/run.sh) to get an idea of how running an experiment works.
1. Skim through the example/default experiment config in [`conf/exp_default.conf`](globalphone-xvectors/conf/exp_default.conf), which shows all available options. Essentially, the idea is that with an appropriate experiment config, you should be able to run an experiment end-to-end with `run.sh` (if your experiment uses x-vector (intermediate) fusion, then you'll need to additionally run [`run_intermediate_fusion.sh`](globalphone-xvectors/run_intermediate_fusion.sh) as well). Here, an _experiment_ consists of preparing the data, training and evaluating the whole system _using a particular combination of feature types_.
1. For even more docs and notes, see [`docs/`](globalphone-xvectors/docs) -- it's brief and contains only explanations that I wrote after desperately not understanding something for hours and then getting it. Some of the docs also touch on very important peculiarities of the GlobalPhone corpus.
1. Create your own experiment config file and pass it to `run.sh` (also familiarise yourself with the other arguments that `run.sh` takes -- they are pretty standard).

NOTE: `cluster.md`, `cluster_setup.sh`, `install_conda.sh` and `install_kaldi.sh` are meant for people making this repo run in the UoE SoI MSc teaching cluster.

If something breaks, try to use your brain, though I cannot absolutely guarantee that all the code is 100% correct. It worked for me.

## Analysing results

Some useful scripts to facilitate results analysis can be found in [`helper-scripts-for-report/`](globalphone-xvectors/helper-scripts-for-report). Even more useful code, graphs of all kinds, additional notes and examples of analysis can be found in my [dissertation repo](https://github.com/samsucik/prosodic-lid-globalphone-dissertation).

## FAQ

**Will you continue this project?**
I'm not planning to, even though this work asks for a continuation -- at least in the form of trying to reproduce my very positive results in a more challenging context -- on more noisy data, such as the NIST LRE datasets. I myself, however, prefer working with text at the moment, not so much with speech.

**Any other question**
Have you tried looking up an answer in my dissertation repo and in this repo? In particular, in the [docs](globalphone-xvectors/docs) and the [example config file](globalphone-xvectors/conf/exp_default.conf)? If yes, and you still don't have an answer, do get in touch with me or file an issue here.
