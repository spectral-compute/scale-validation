#!/bin/bash

set -ETeuo pipefail

LOGFILE="profiler.log"
OUTDIR="profiler"

echo "Writing to $LOGFILE and outputting CSV to directory ${OUTDIR}/"
rm -rf "$LOGFILE" "${OUTDIR}"
mkdir "${OUTDIR}"

# Run the profiler for each operation. Trmm and Symm are omitted as they're not currently working.
for OP in gemm block_scaled_gemm blockwise_gemm spgemm conv2d conv3d rank_k rank_2k grouped_gemm ; do
    build/tools/profiler/cutlass_profiler --operation="${OP}" --output="${OUTDIR}/cutlass_profiler" \
        |& tee -a "${LOGFILE}"
done
