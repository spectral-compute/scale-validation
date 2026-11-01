"""Check the quality of tsne-cuda's embedding of labelled Gaussian clusters.

t-SNE's output depends on floating-point reduction order, so it isn't compared against a reference.
Instead, each embedding must preserve local neighbourhoods and keep the clusters apart about as well
as it does on NVIDIA (the thresholds leave a margin below the values NVIDIA's embeddings reach).
"""

import sys

import numpy as np
import tsnecuda


def knn(x, k):
    """Indices of each point's k nearest neighbours (excluding itself), by squared L2 distance."""
    x = x.astype(np.float64)
    sq = (x * x).sum(axis=1)
    out = np.empty((len(x), k), dtype=np.int64)
    for i in range(0, len(x), 1000):
        d = sq[i:i + 1000, None] - 2 * x[i:i + 1000] @ x.T + sq[None, :]
        d[np.arange(len(d)), np.arange(i, i + len(d))] = np.inf
        part = np.argpartition(d, k, axis=1)[:, :k]
        order = np.take_along_axis(d, part, axis=1).argsort(axis=1)
        out[i:i + 1000] = np.take_along_axis(part, order, axis=1)
    return out


def clusters(n, dims, n_clusters, spread, rng):
    centres = rng.normal(scale=spread, size=(n_clusters, dims))
    labels = rng.integers(n_clusters, size=n)
    return (centres[labels] + rng.normal(size=(n, dims))).astype(np.float32), labels


def check(name, x, labels, k=10, min_preserved=None, min_1nn=None, min_separation=None,
          **tsne_args):
    print(f"== {name}: {x.shape[0]} points, {x.shape[1]} dims, {tsne_args}", flush=True)
    y = tsnecuda.TSNE(**tsne_args).fit_transform(x)

    if not np.isfinite(y).all():
        print(f"FAIL: {np.count_nonzero(~np.isfinite(y))} non-finite coordinates")
        return False

    high, low = knn(x, k), knn(y, k)
    # Fraction of each point's k nearest neighbours in the input that are still among its k
    # nearest neighbours in the embedding.
    preserved = np.mean([len(np.intersect1d(a, b)) / k for a, b in zip(high, low)])
    # Leave-one-out 1-NN classification accuracy in the embedding.
    nn1 = np.mean(labels[low[:, 0]] == labels)
    # Distance between the two closest cluster centroids, relative to the mean RMS cluster radius.
    ids = np.unique(labels)
    centroids = np.array([y[labels == c].mean(axis=0) for c in ids])
    radius = np.mean([np.sqrt(((y[labels == c] - centroids[i]) ** 2).sum(axis=1).mean())
                      for i, c in enumerate(ids)])
    gaps = np.linalg.norm(centroids[:, None] - centroids[None, :], axis=2)
    separation = gaps[~np.eye(len(ids), dtype=bool)].min() / radius
    print(f"extent {np.ptp(y, axis=0)}, {k}-NN preserved {preserved:.4f}, 1-NN accuracy "
          f"{nn1:.4f}, cluster separation {separation:.3f}")

    ok = True
    for metric, value, threshold in (("preserved", preserved, min_preserved),
                                     ("1-NN accuracy", nn1, min_1nn),
                                     ("separation", separation, min_separation)):
        if threshold is not None and value < threshold:
            print(f"FAIL: {metric} {value:.4f} < {threshold}")
            ok = False
    return ok


rng = np.random.default_rng(1)
ok = True

# NVIDIA (sm_61) reaches 10-NN preserved 0.027, 1-NN accuracy 1.0 and separation 5.3 here. Within a
# well-separated cluster, local structure is mostly noise, so preservation is low but well above chance
# (0.005); a random embedding scores ~0.001 and 0.1.
x, labels = clusters(20000, 50, 10, 1.0, rng)
ok &= check("separated clusters", x, labels, min_preserved=0.02, min_1nn=0.99, min_separation=3.0)
# NVIDIA: 0.029, 1.0.
ok &= check("separated clusters, inner product", x, labels, metric="innerproduct",
            min_preserved=0.02, min_1nn=0.99)

# NVIDIA: 0.160, 0.612 (the clusters overlap, so separation is meaningless).
x, labels = clusters(10000, 50, 10, 0.4, rng)
ok &= check("overlapping clusters, perplexity 10", x, labels, perplexity=10, learning_rate=100,
            min_preserved=0.14, min_1nn=0.55)

sys.exit(0 if ok else 1)
