#!/bin/bash

set -ETeuo pipefail

cmake \
	-DGGML_CUDA=ON \
	-DCMAKE_INSTALL_PREFIX="install_ggml" \
	-B "build_ggml" \
	"ggml"

make -C "build_ggml" install -j"$(nproc)"
