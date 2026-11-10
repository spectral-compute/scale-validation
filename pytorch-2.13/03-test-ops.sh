#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Run the benchmarked ops (benchmarks/bench.py) and log their times.
source pytorch/.venv/bin/activate
python "${SCRIPT_DIR}/benchmarks/bench.py"
