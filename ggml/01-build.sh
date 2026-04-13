#!/bin/bash

set -ETeuo pipefail

GGML_NATIVE=On
if [ "${NO_TUNE_NATIVE:-0}" == "1" ]; then
    GGML_NATIVE=Off
fi

cmake \
	-DGGML_CUDA=ON \
	-DCMAKE_INSTALL_PREFIX="install_ggml" \
    -DGGML_NATIVE=$GGML_NATIVE \
	-B "build_ggml" \
	"ggml"

make -C "build_ggml" install -j"$(nproc)"
