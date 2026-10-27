#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

MPI_DIR="$(realpath ../openmpi/install)"
export PATH="${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${LD_LIBRARY_PATH:-}"
# hypre stages its MPI buffers through host memory (no GPU-aware MPI, no
# unified memory), so keep OpenMPI's device-pointer checks out of the timings,
# identically for every toolchain.
export OMPI_MCA_accelerator=null
export OMPI_MCA_rmaps_base_oversubscribe=1

RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "$RESULTS_DIR"

# scale, nvcc or hip. TEST_GPU_ARCH tells SCALE on AMD from SCALE on NVIDIA.
stem="$BENCHMARK_COMPILER.$TEST_GPU_ARCH"
data_file="$RESULTS_DIR/hypre.$stem.$(date '+%Y%m%d-%H%M%S').${BENCHMARK_REPEAT:-1}.csv"

cd build/src/test

# TEST_bench: BoomerAMG-PCG (ij), SpGEMM (ij_mm) and struct PCG on the device.
# Each job runs several MPI ranks; they share GPUs round-robin, so pass
# benchmark.py one device (-d) to compare toolchains like for like.
# The saved timings are LLNL's machines, so don't compare against them.
rm -f TEST_bench/*.out* TEST_bench/*.err*
HYPRE_NO_SAVED=1 ./runtest.sh -t -mpi "$(command -v mpirun) -np" TEST_bench/*.sh

for f in TEST_bench/*.err; do
    if [ -s "$f" ]; then
        log "Errors from ${f}:"
        head -n 40 "$f" >&2
    fi
done

# Each benchmark's .sh collects its timings into <benchmark>.perf.out, as
# "# Output file: <benchmark>.out.<case>" followed by
# "<phase> wall clock time = <seconds> seconds" lines. Only move the CSV into
# RESULTS_DIR if it has timings, so failed runs don't leave empty files there.
{
    echo "benchmark,case,phase,seconds"
    awk '
        /^# Output file:/ { n = split($4, p, "."); bench = p[1]; c = p[n]; next }
        / wall clock time = / {
            phase = $0
            sub(/ wall clock time = .*/, "", phase)
            sub(/^ +/, "", phase)
            secs = $0
            sub(/.* wall clock time = /, "", secs)
            sub(/ seconds.*/, "", secs)
            printf "%s,%s,%s,%s\n", bench, c, phase, secs
        }
    ' TEST_bench/*.perf.out
} >timings.csv

if [[ "$(wc -l <timings.csv)" -le 1 ]]; then
    log "hypre benchmarks produced no timings"
    exit 1
fi
mv timings.csv "$data_file"
log "Wrote $(($(wc -l <"$data_file") - 1)) timings to $data_file"
