# Partitioning the data

## Datasets we're after
In essence, Global Phone comes with three datasets (train, dev, eval), but we need 4 separate datasets:
1. Training: To train the X-vector DNN
1. Enrollment: To train the classifier
1. Evaluation: For end-to-end evaluation in order to tune hyperparameters
1. Test: For final evaluation or comparison of approaches on unseen data

The decision is to have the data split roughly 70:10:10:10, i.e. the X-vector DNN is trained on 70% of the speakers, with the speakers of each language split roughly in the same proportion.

## Characteristics of the partitioning
The basic (and only) constraints desirable across the datasets are (following the original approach by the authors of Global Phone):
1. "No speaker appears in more than one group"
1. "No article was read by two speakers from different groups"

Where possible, the original sets from the `gp v5` Kaldi recipe are re-used (with the original `eval` here used as the testing data, and `dev` used as the evaluation data). These are heavily based on the splitting presented in the Global Phone documentation. 

At the very least, the splitting of the original `train` speakers into training and enrollment speakers needs to be carried out. For languages where no original splitting was present in the `gp v5` recipe (Arabic, Wu and Tamil), all four datasets need to be constructed.

## How to

### Prepare speaker metadata
This means scraping from the Global Phone corpus the lists of articles read by every speaker. Execute like this:
```bash
local/gp_speaker_metadata_scraper.sh \
	--lang-map=conf/lang_codes.txt \
	--corpus-dir=/disk/scratch/lid/global_phone \
	--output-dir=speakers
```

This stores language+speaker-specific article metadata in `speakers/XX_spk_metadata`.

Note that there is no article data (or speaker metadata generally) available for Bulgarian, French, German, Polish, Tamil, Thai and Vietnamese. For these languages, the datasets are constructed randomly.

### Prepare all speakers lists
For simplicity, language-specific lists of all speakers are also made available in `speakers/XX_all_spk`. Assuming you've followed the instructions on converting SHN files to WAVs ([see here](processing_wavs.md)), you'll have the list of all speakers with valid WAV utterances in a language specific directory such as `FR/lists/spk` inside the directory where you decided to store all the WAVs (`~/lid/wav/` in my case).

To move the relevant lists into `speakers/`, run the following (adjust as needed):
```bash
for L in AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU VN WU; do
	cp ~/lid/wav/$L/lists/spk speakers/spk
	mv speakers/spk speakers/${L}_all_spk
done
```

### Split speakers for each language into datasets
Execute like this:
```bash
local/gp_partition_speakers.py
```

This script loads the original splittings from `conf/gp_original_dev_spk.list` and `conf/gp_original_eval_spk.list`, speaker metadata from `speakers/XX_spk_metadata`, lists of all speakers per language from `speakers/XX_all_spk` and in the code is stored also the number of speakers per language.

For languages that lack the information on articles read by speakers, the datasets are constructed randomly (and yes, if you run the script repeatedly, they will differ!). For the other languages, the main trick used to create the splitting is, well, brute force: Random splitting is created and the amount of article overlaps is checked (speaker overlap *never happens*). If the overlap is acceptable (ideally none), the splitting is returned. If the algorithm tries too many times (e.g. 100000) and cannot find a valid splitting, the number of acceptable article overlaps is increased from the initial 0 to 1, 2, etc. This way, the script will *always* find a partitioning. If you wanna push hard, increase the `max_iter` parameters inside the script to try harder and maybe find a partitioning with fewer overlaps.

The partitioning for each language is stored in `speakers/` as `XX_test`, `XX_eval`, `XX_enroll` and `XX_train`.