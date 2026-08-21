#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

GGML_NATIVE=On
if [ "${NO_TUNE_NATIVE:-0}" == "1" ]; then
    GGML_NATIVE=Off
fi

args=(
    -DCMAKE_INSTALL_PREFIX="install_ggml"
    -DGGML_NATIVE="$GGML_NATIVE"

    -DGGML_CUDA=ON
)

cmake \
    "${args[@]}" \
    -B "build_ggml" \
    "ggml"

make -O -C "build_ggml" install -j"$(nproc)"
