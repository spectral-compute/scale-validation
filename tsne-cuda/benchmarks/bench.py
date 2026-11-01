"""Time tsne-cuda on synthetic clustered data, in a subprocess per case.

Prints one CSV row per case: wall time of fit_transform, then tsne-cuda's own per-phase timers.
"""

import os
import subprocess
import sys
import time

import numpy as np

# name: (points, dims, clusters)
CASES = {
    "clusters-100k-50d": (100_000, 50, 10),
    "mnist-sized-60k-784d": (60_000, 784, 10),
    "clusters-1m-50d": (1_000_000, 50, 20),
}


def run_case(name):
    import tsnecuda

    n, dims, k = CASES[name]
    rng = np.random.default_rng(0)
    centres = rng.normal(scale=1.0, size=(k, dims))
    x = (centres[rng.integers(k, size=n)] + rng.normal(size=(n, dims))).astype(np.float32)
    # verbose=1 prints the phase timers; the huge print interval keeps it from adding a
    # gradient-norm reduction (a host sync) every 10 iterations.
    tsne = tsnecuda.TSNE(verbose=1, print_interval=1 << 30)
    start = time.perf_counter()
    y = tsne.fit_transform(x)
    wall = time.perf_counter() - start
    sys.stdout.flush()
    assert np.isfinite(y).all(), "non-finite embedding"
    print(f"wall_time: {wall}s", flush=True)


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--case":
        run_case(sys.argv[2])
        return

    print("case,wall_time,initialization,knn,symmetry,init_low_dim,init_fft,compute_charges,"
          "precompute_2d,nbodyfft,norm,attr,apply_forces,other,total_time")
    for name in CASES:
        out = subprocess.run([sys.executable, __file__, "--case", name], check=True,
                             stdout=subprocess.PIPE, text=True).stdout
        sys.stderr.write(out)
        timers = {}
        for line in out.splitlines():
            key, sep, value = line.partition(": ")
            if sep and value.endswith("s"):
                try:
                    timers[key.removeprefix("_time_")] = float(value[:-1])
                except ValueError:
                    pass
        fields = ["wall_time", "initialization", "knn", "symmetry", "init_low_dim", "init_fft",
                  "compute_charges", "precompute_2d", "nbodyfft", "norm", "attr", "apply_forces",
                  "other", "total_time"]
        print(",".join([name] + [str(timers[f]) for f in fields]), flush=True)


if __name__ == "__main__":
    main()
