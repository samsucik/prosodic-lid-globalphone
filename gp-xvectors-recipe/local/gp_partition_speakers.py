#!/usr/bin/env python3

# Copyright 2019 Sam Sucik
# 
# Apache 2.0

import re
from math import floor, ceil
import random
import argparse, sys

def load_speaker_data(langs):
    spk_dict = {}
    for L in langs:
        speakers_for_language = {}
        try:
            with open("speakers/{}_spk_metadata".format(L), "r") as spk_file:
                for line in spk_file.readlines():
                    line_splitted = line.split("|")
                    spk_id = line_splitted[0]
                    spk_articles = line_splitted[1].split(",")
                    spk_articles = [article.strip() for article in spk_articles]
                    speakers_for_language[spk_id] = spk_articles
                spk_dict[L] = speakers_for_language
        except:
            pass
            
    return spk_dict

def load_all_speakers(langs):
    spk_lists = {}
    for L in langs:
        speakers_for_language = []
        try:
            with open("speakers/{}_all_spk".format(L), "r") as spk_file:
                for line in spk_file.readlines():
                    spk_id = line.strip()
                    speakers_for_language.append(spk_id)
        except:
            pass
        spk_lists[L] = speakers_for_language

    return spk_lists

def load_original_datasets(langs):
    datasets_dict = {L: {"eval": [], "test": []} for L in langs}

    try:
        with open("conf/gp_original_dev_spk.list", "r") as spk_file:
            for line in spk_file.readlines():
                line_split = [x.strip() for x in re.split('\t| ', line)]
                # In case there is no split (lines like "AR TBA")
                if len(line_split) <= 2:
                    continue

                language = line_split[0]
                if language in langs:
                    spk_ids = line_split[1:]
                    for spk_id in spk_ids:
                        datasets_dict[language]["eval"].append(spk_id)
    except:
        print("Couldn't open the dev spk original list.")
        pass

    try:
        with open("conf/gp_original_eval_spk.list", "r") as spk_file:
            for line in spk_file.readlines():
                line_split = [x.strip() for x in re.split('\t| ', line)]
                
                # In case there is no split (lines like "AR TBA")
                if len(line_split) <= 2:
                    continue

                language = line_split[0]
                if language in langs:   
                    spk_ids = line_split[1:]
                    for spk_id in spk_ids:
                        datasets_dict[language]["test"].append(spk_id)
    except:
        print("Couldn't	open the eval spk original list.")
        pass

    return datasets_dict


if __name__ == "__main__":
    num_spks = {"AR": 78, "BG": 77, "CH": 132, "CR": 92, "CZ": 102, "FR": 100, "GE": 77, 
                "JA": 144, "KO": 100, "PL": 99, "PO": 100, "RU": 115, "SP": 100, 
                "SW": 98, "TA": 47, "TH": 98, "TU": 100, "VN": 129, "WU": 41}
    all_langs = ["AR", "BG", "CH", "CR", "CZ", "FR", "GE", "JA", "KO", "PL", 
                 "PO", "RU", "SP", "SW", "TA", "TH", "TU", "VN", "WU"]


    parser=argparse.ArgumentParser()
    parser.add_argument('--langs', help='List of language codes to work with (default: all languages)')
    args=parser.parse_args()
    if args.langs is not None:
        all_langs = args.langs.split()

    print("Partitioning spekaers for languages: {}.".format(", ".join(all_langs)))

    
    spk_article_dict = load_speaker_data(all_langs)
    langs_with_spk_data = list(spk_article_dict.keys())
    # print("SPK data exists for these langs: {}".format(langs_with_spk_data))
    langs_for_random_split = [lang for lang in all_langs if lang not in langs_with_spk_data]
    # print("SPK data NOT found for these langs: {}".format(langs_for_random_split))

    all_spk_lists = load_all_speakers(all_langs)

    gp_original_sets = load_original_datasets(all_langs)

    print(gp_original_sets)

    for L in all_langs:
        print("Partitioning {} speakers.".format(L))
        eval_set = gp_original_sets[L]["eval"]
        test_set = gp_original_sets[L]["test"]
        available_spks = [spk_id for spk_id in all_spk_lists[L] if \
                          (spk_id not in eval_set and spk_id not in test_set)]
        
        spks_test = test_set
        spks_eval = eval_set
        spks_enroll = []
        spks_train = []

        if (len(eval_set) + len(test_set)) == 0:
            num_enroll = int(floor(0.1*num_spks[L]))
            num_test = num_enroll
            num_eval = num_enroll
            print("No original partitioning found. Creating all four datasets: {} = {} + {} + {} + rest."\
                  .format(num_spks[L], num_test, num_eval, num_enroll))

            # The most complicated case: 4 non-random sets
            if L in langs_with_spk_data:
                print("Spk metadata present. Using it for the split.")
                
                sets_valid = False
                attempt_counter = 0
                threshold = 0
                max_iter = 10000

                while not sets_valid:
                    spks_test = random.sample(available_spks, num_test)
                    spks_eval = random.sample([spk_id for spk_id in available_spks \
                                               if spk_id not in spks_test], num_eval)
                    spks_enroll = random.sample([spk_id for spk_id in available_spks \
                                                 if (spk_id not in spks_test) \
                                                 and (spk_id not in spks_eval)], num_enroll)
                    spks_train = [spk_id for spk_id in available_spks \
                                  if (spk_id not in spks_test) \
                                  and (spk_id not in spks_eval) \
                                  and (spk_id not in spks_enroll)]

                    test_articles = []
                    for spk_id in spks_test:
                        test_articles = test_articles + spk_article_dict[L].get(spk_id, [])
                    test_articles = set(test_articles)
                    
                    eval_articles = []
                    for spk_id in spks_eval:
                        eval_articles = eval_articles + spk_article_dict[L].get(spk_id, [])
                    eval_articles = set(eval_articles)

                    enroll_articles = []
                    for spk_id in spks_enroll:
                        enroll_articles = enroll_articles + spk_article_dict[L].get(spk_id, [])
                    enroll_articles = set(enroll_articles)

                    train_articles = []
                    for spk_id in spks_train:
                        train_articles = train_articles + spk_article_dict[L].get(spk_id, [])
                    train_articles = set(train_articles)

                    overlap = len(test_articles) + len(eval_articles) + len(enroll_articles) + len(train_articles) \
                              - len(train_articles.intersection(test_articles, eval_articles, enroll_articles))

                    # Valid partitioning found
                    if overlap <= threshold:
                        print("Article overlap: {}".format(overlap))
                        break

                    # Invalid partitioning found
                    else:
                        attempt_counter += 1
                        if attempt_counter % max_iter == 0:
                            threshold += 1
                            print("Looking for splits with <= {} overlaps.".format(threshold))
            
            # The easy case: 4 random sets
            else:
                print("No spk metadata found. Doing random split.")
                spks_test = random.sample(available_spks, num_test)
                spks_eval = random.sample([spk_id for spk_id in available_spks \
                                           if spk_id not in spks_test], num_eval)
                spks_enroll = random.sample([spk_id for spk_id in available_spks \
                                             if (spk_id not in spks_test) \
                                             and (spk_id not in spks_eval)], num_enroll)
                spks_train = [spk_id for spk_id in available_spks \
                              if (spk_id not in spks_test) \
                              and (spk_id not in spks_eval) 
                              and (spk_id not in spks_enroll)]

        else:
            num_enroll = int(floor(0.1*num_spks[L]))
            print("Original partitioning found. Creating train/enroll datasets: {} = {} + {}."\
                  .format(len(available_spks), num_enroll, len(available_spks) - num_enroll))
            
            # The complicated case: 2 non-random sets
            if L in langs_with_spk_data:
                print("Spk metadata present. Using it for the split.")
                
                sets_valid = False
                attempt_counter = 0
                threshold = 0
                max_iter = 100000
                
                while not sets_valid:
                    spks_enroll = random.sample(available_spks, num_enroll)
                    spks_train = [spk_id for spk_id in available_spks if spk_id not in spks_enroll]
                    
                    enroll_articles = []
                    for spk_id in spks_enroll:
                        enroll_articles = enroll_articles + spk_article_dict[L].get(spk_id, [])
                    
                    enroll_articles = set(enroll_articles)
                    
                    train_articles = []
                    for spk_id in spks_train:
                        train_articles = train_articles + spk_article_dict[L].get(spk_id, [])
                    train_articles = set(train_articles)

                    overlap = list(train_articles.intersection(enroll_articles))

                    # Valid partitioning found
                    if len(overlap) <= threshold:
                        print("Article overlap: {}".format(len(overlap)))
                        break

                    # Invalid partitioning found
                    else:
                        attempt_counter += 1
                        if attempt_counter % max_iter == 0:
                            threshold += 1
                            print("Looking for splits with <= {} overlaps.".format(threshold))

            # The easiest case: 2 random sets
            else:
                print("No spk metadata found. Doing random split.")
                spks_enroll = random.sample(available_spks, num_enroll)
                spks_train = [spk_id for spk_id in available_spks if spk_id not in spks_enroll]

        spks_test.sort()
        spks_eval.sort()
        spks_enroll.sort()
        spks_train.sort()

        print("Testing speakers: {}".format(spks_test))
        print("Evaluation speakers: {}".format(spks_eval))
        print("Enrollment speakers: {}".format(spks_enroll))
        print("Training speakers: {}".format(spks_train))

        with open("speakers/{}_test".format(L), "w") as f:
            f.write(' '.join(spks_test))
        with open("speakers/{}_eval".format(L), "w") as f:
            f.write(' '.join(spks_eval))
        with open("speakers/{}_enroll".format(L), "w") as f:
            f.write(' '.join(spks_enroll))
        with open("speakers/{}_train".format(L), "w") as f:
            f.write(' '.join(spks_train))
