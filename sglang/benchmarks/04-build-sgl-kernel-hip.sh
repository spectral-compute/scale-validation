#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

source .venv/bin/activate
python -m pip install "setuptools>=75" "scikit-build-core>=0.10" wheel ninja

# As upstream's rocm.Dockerfile builds it.
cd sglang/python/sglang/kernels/aot
AMDGPU_TARGET="${TEST_GPU_ARCH}" MAX_JOBS="$(nproc)" python setup_rocm.py install
