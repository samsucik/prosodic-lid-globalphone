# Logit classifier
*Notes by Sam.*

The logistic regression in Kaldi is rather peculiar, definitely not the vanilla logit one would imagine.

# Hyperparameters
`max-steps`: Maximum steps in L-BFGS (default: 20).
`normalizer`: Coefficient for L2 regularization (default: 0.0025).
`power`: Power rule for determining the number of mixtures to create (default: 0.15).
`mix-up`: Target number of mixture components to create (default: 0).

# Training pipeline
*Essentially, `logistic-regression.cc` explained.*

Have `K` classes, training examples `X` and targets `y`.

1. Train classic multiclass logit with `K` classes (`LogisticRegression::Train`) -- assuming that each class is modelled as one chunk in space/one mixture component. The trained weight matrix is `W`
1. If `mix-up` > `K`, continue with training (otherwise, we're finished): Try and model the data by using not `K`, but `mix-up` chunks/mixture components.
1. Use `GetSplitTargets()` to determine the highest number of chunks `C` (`C` <= `mix-up`) that the training examples can be divided into such that each chunk contains at least `N` data points (`N` is called `min_count` in `LogisticRegression::MixUp`, and is hard-coded as 1). Do this in a while loop (`C` <= `mix-up`) by always splitting the biggest class (biggest in terms of number of data points per chunk). Don't split classes that would then have fewer than `N` data points in some chunk.
1. In `LogisticRegression::MixUp`, inflate `W` to model not `K`, but `C` chunks. Essentially, for each class `k`, add `N_k - 1` rows to `W` (by copying the original, pre-trained row for class `k`), and add random noise to every one of these duplicates. This way, for each class `k`, we have `N_k` slightly different boundaries that model it (separate it from the rest of the samples).
1. Retrain the inflated `W`.

The `power` parameter is used to bring the occupancies of all classes closer together in the `GetSplitTargets()` function: If a class originally contains `d` data points, its occupancy is taken to be `d^power`. If `power` is closer to 1, the classes' sizes are less close to each other, and bigger classes will get split into many more chunks than smaller ones. As `power` approaches 0, even small classes will get split. For instance, taking `power = 0.15` having class `k_1` with 1500 samples and `k_2` with 700 samples, after splitting `k_1` into 2 chunks, its per-chunk occupancy is `1.498` and `k_2`'s per-chunk occupancy is `2.67`, so now `k_2` would be split with higher priority than `k_1`.
