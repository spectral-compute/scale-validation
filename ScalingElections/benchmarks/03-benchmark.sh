#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

cd ScalingElections
. .venv/bin/activate

# Times the GPU Schulze solver (the upstream benchmark's "Tiled GPU (CUDA)" case) on random
# preference matrices. Upstream's driver also runs the serial Numba solver to name a winner,
# which takes hours at the sizes in its README, so this calls the extension directly.
# Each time covers one compute_strongest_paths() call, including its allocation and copies.
OUT="${RESULTS_DIR:-$(realpath ..)}/scalingelections.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"
python - "${OUT}" <<'PY'
import sys, time
import numpy as np
from scaling_elections import compute_strongest_paths

rows = ["candidates,repeats,best_ms,median_ms,gcells_per_s"]
for n, repeats in ((2048, 5), (4096, 3), (8192, 3)):
    preferences = np.random.default_rng(n).integers(0, n, (n, n)).astype(np.uint32)
    run = lambda: compute_strongest_paths(preferences, allow_gpu=True, allow_tma=False, tile_size=32)
    run()
    times = []
    for _ in range(repeats):
        start = time.perf_counter()
        run()
        times.append(time.perf_counter() - start)
    best, median = min(times), sorted(times)[len(times) // 2]
    rows.append(f"{n},{repeats},{best * 1e3:.1f},{median * 1e3:.1f},{n**3 / best / 1e9:.1f}")
    print(rows[-1], flush=True)
open(sys.argv[1], "w").write("\n".join(rows) + "\n")
PY
cat "${OUT}"
