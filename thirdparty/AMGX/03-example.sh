#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/AMGX/AMGX/build"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"

for MODE in dFFI dDDI ; do
    echo -e "\x1b[34;1mVariant\x1b[m: \x1b[1m${MODE}\x1b[m"
    examples/amgx_capi -m ../examples/matrix.mtx -c ../src/configs/FGMRES_AGGREGATION.json -mode ${MODE}
done
