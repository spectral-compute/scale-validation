#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

cmake \
	-DGGML_CUDA=ON \
	-DCMAKE_INSTALL_PREFIX="$OUT_DIR/install_ggml" \
	-B "$OUT_DIR/build_ggml" \
	"$OUT_DIR/ggml/ggml"

# --- Run make ---
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -C "$OUT_DIR/build_ggml" install -j"${BUILD_JOBS}" ${VERBOSE}