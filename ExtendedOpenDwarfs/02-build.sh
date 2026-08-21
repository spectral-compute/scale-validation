#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd ExtendedOpenDwarfs

export LC_ALL=C
export LANG=C

export APP="${EOD_APP:-${TEST_APP:-fft}}"
export BACKEND="${EOD_BACKEND:-${TEST_BACKEND:-cuda}}"
export COMPILER="${EOD_COMPILER:-${TEST_COMPILER:-scale-amd}}"
export SIZE="${EOD_SIZE:-${TEST_SIZE:-tiny}}"
export ITERS="${EOD_ITERS:-${TEST_ITERS:-1}}"

# scale-validation injects compiler diagnostic flags globally.
# EOD manages its own flags; keep the harness from poisoning SCALE/AMD builds.
unset CFLAGS
unset CXXFLAGS
unset NVCC_PREPEND_FLAGS
unset NVCC_APPEND_FLAGS
unset CMAKE_COLOR_DIAGNOSTICS

case "$APP" in
crc)
    make -C combinational-logic/crc clean
    make -C combinational-logic/crc datasets
    ;;

cfd)
    [[ -f test/unstructured-grids/cfd/128.dat ]] ||
        python3 scripts/generate_cfd_dataset.py \
            test/unstructured-grids/cfd/fvcorr.domn.193K \
            test/unstructured-grids/cfd/128.dat \
            128

    [[ -f test/unstructured-grids/cfd/1284.dat ]] ||
        python3 scripts/generate_cfd_dataset.py \
            test/unstructured-grids/cfd/fvcorr.domn.193K \
            test/unstructured-grids/cfd/1284.dat \
            1284

    [[ -f test/unstructured-grids/cfd/45056.dat ]] ||
        python3 scripts/generate_cfd_dataset.py \
            test/unstructured-grids/cfd/fvcorr.domn.193K \
            test/unstructured-grids/cfd/45056.dat \
            45056

    [[ -f test/unstructured-grids/cfd/193474.dat ]] ||
        python3 scripts/generate_cfd_dataset.py \
            test/unstructured-grids/cfd/fvcorr.domn.193K \
            test/unstructured-grids/cfd/193474.dat \
            193474
    ;;
esac

if [[ "$COMPILER" == scale-* ]]; then
    export ODW_USE_SCALE=1
fi

make build \
    APP="$APP" \
    BACKEND="$BACKEND" \
    COMPILER="$COMPILER" \
    SIZE="$SIZE" \
    ITERS="$ITERS"
