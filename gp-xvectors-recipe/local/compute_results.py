#!/usr/bin/env python3

"""
A very simple error calculator.
Takes the scores file as input, prints the error rate for each language.
For each utterance, classifies it as the most likely of all the languages scores
"""
import argparse
import numpy as np
from collections import OrderedDict
from sklearn.metrics import confusion_matrix

# Cost values from https://www.nist.gov/sites/default/files/documents/2017/06/01/lre17_eval_plan-2017-05-31_v2.pdf
c_fa = 1
c_miss = 1

def get_args():
    parser = argparse.ArgumentParser(description="Calculates score for each language",
                                 epilog="Called by run.sh")
    parser.add_argument("--classification-file", type=str, required=True,
                    help="File with all utterances, classification pairs, e.g. exp/classification")
    parser.add_argument("--output-file", type=str, required=True,
                    help="Name of file to which results will be dumped, e.g. exp/results")
    parser.add_argument("--conf-mtrx-file", type=str, required=True,
                    help="Name of file to which the CSV confusion mtrix will be dumped, e.g. exp/conf_mtrx.csv")
    parser.add_argument("--language-list", type=str, required=True,
                    help="Ordered string of all languages, e.g. 'GE KO SW'")
    args = parser.parse_args()
    return args

# Sums all the p_miss for target languages in the matrix, using efficient matrix operations
# Separate to p_miss function in case that is used for something else e.g. Equation (5)
def find_sum_p_miss(conf_matrix):
    accurate = np.diag(conf_matrix)
    ideal = np.sum(conf_matrix, axis=1)
    return np.sum((ideal - accurate) / ideal)

def find_sum_p_fa(conf_matrix, languages):
    n = conf_matrix.shape[0]
    p_fa_sum = 0
    # Swapping i and j simply since j refers to columns, and i to rows
    for j in range(n):
        num_predicted = np.sum(conf_matrix[:, j])
        if num_predicted == 0:
            # print("WARNING:")
            # print("No predictions for language {} in the confusion matrix.".format(languages[j]))
            continue
        for i in range(n):
            if i == j:
                # skip if it's the correct value (not a false positive)
                continue
            num_fa = conf_matrix[i][j]
            p_fa = num_fa/num_predicted
            p_fa_sum += p_fa
    return p_fa_sum

# From Equation(6) in the LRE paper
def find_c_avg(beta, n, sum_p_miss, sum_p_fa):
    return float(1)/n * (sum_p_miss + (float(1)/(n-1)) * (beta * sum_p_fa))

def find_c_primary(conf_matrix, languages):
    n = conf_matrix.shape[0]
    p_target_values = [0.5, 0.1]
    sum_p_fa = find_sum_p_fa(conf_matrix, languages)
    sum_p_miss = find_sum_p_miss(conf_matrix)
    c_sum = 0
    for p_target in p_target_values:
        beta = (c_fa * (1 - p_target)) / (c_miss * p_target)
        c_sum += find_c_avg(beta, n, sum_p_miss, sum_p_fa)
    return c_sum/2

def make_stats(classification_file, output_file, conf_mtrx_file, languages):
    with open(classification_file, "r") as f:
        # From lines like "GE001_33 KO" make simple pairs (true, predicted) like [GE, KO]
        classifications = np.array([[l.split()[0][:2], l.split()[1]] for l in f.readlines()])
        y_true = classifications[:, 0]
        y_pred = classifications[:, 1]
        conf_matrix = confusion_matrix(y_true, y_pred, labels=languages)
        langs_string = ",".join(languages)
        np.savetxt(conf_mtrx_file, conf_matrix, delimiter=",", header=langs_string)

        # Accuracy (sum along the diagonal of the conf. matrix)
        accuracy = np.trace(conf_matrix)/np.sum(conf_matrix)
        acc_msg = "Accuracy: {:.4f} ({}/{} classified correctly)"\
            .format(accuracy, np.trace(conf_matrix), np.sum(conf_matrix))
        print(acc_msg)

        # Pretty-printing the conf. matrix
        n = 4
        conf_matrix_nice = [languages[i].ljust(n) + " ".join([str(e).ljust(n) for e in row]) \
            for i, row in enumerate(conf_matrix)]
        conf_mtrx_msg = "Confusion matrix:\n{}{}\n{}".format(
                            " "*n,
                            " ".join([l.ljust(n) for l in languages]),
                            "\n".join(conf_matrix_nice))
        print(conf_mtrx_msg)

        # C primary calculation
        c_primary = find_c_primary(conf_matrix, languages)
        c_primary_msg = "C_primary value: {:.4f}".format(c_primary)
        print(c_primary_msg)

        # Write results to file
        with open(output_file, "w") as o:
            o.write("{}\n".format(acc_msg))
            o.write("{}\n".format(conf_mtrx_msg))
            o.write("{}\n".format(c_primary_msg))

if __name__ == "__main__":
    args = get_args()
    languages = args.language_list.split()
    make_stats(args.classification_file, args.output_file, args.conf_mtrx_file, languages)
