#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

LOGFILE="profiler.log"
OUTDIR="profiler"

log "Writing to $LOGFILE and outputting CSV to directory ${OUTDIR}/"
rm -rf "$LOGFILE" "${OUTDIR}"
mkdir "${OUTDIR}"

# Run the profiler for each operation. Trmm and Symm are omitted as they're not currently working.
for OP in gemm block_scaled_gemm blockwise_gemm spgemm conv2d conv3d rank_k rank_2k grouped_gemm; do
    build/tools/profiler/cutlass_profiler --operation="${OP}" --output="${OUTDIR}/cutlass_profiler" |&
        tee -a "${LOGFILE}"
done

# copy the CSVs (together with GPU info) to provide a convenient way to retrieve the profiler output
RESULTS_DIR="/tmp/ci_benchmarks"
rm -rf "$RESULTS_DIR"
mkdir "$RESULTS_DIR"
if which scaleinfo >/dev/null 2>&1; then
    scaleinfo >"${OUTDIR}/scale_info.txt"
else
    lspci | grep -i vga >"${OUTDIR}/pci_info.txt"
fi

log "Copying ${OUTDIR} to ${RESULTS_DIR}/"
cp -r "${OUTDIR}" "${RESULTS_DIR}/"
