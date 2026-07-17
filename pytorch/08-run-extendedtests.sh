#!/usr/bin/env bash

set -ETeuo pipefail

# TODO(#1144): Kill each of these if possible.
#
# Keep PyTorch on the GPU selected by CI
# Fall back to the first GPU when CI has not already selected one
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

# PyTorch's addmm uses cuBLASLt, which SCALE does not support yet. Without this the
# TF32 runs fail with:
#   RuntimeError: CUDA error: CUBLAS_STATUS_NOT_SUPPORTED when calling
#   `cublasLtMatmulDescCreate(&raw_descriptor, compute_type, scale_type)`
# This makes PyTorch fall back to plain cuBLAS.
export DISABLE_ADDMM_CUDA_LT=1

source pytorch/.venv/bin/activate

# Setup import paths
SCRIPT_DIR="$(dirname "$(realpath $0)")"
SUITE_ROOT="$SCRIPT_DIR/pytorch_extended_tests"
export PYTHONPATH="$SUITE_ROOT/src:$SUITE_ROOT:${PYTHONPATH-}"

[ -d results ] || mkdir results

python -u -m pytorch_extended_tests.orchestrator.run_suite \
    --results-dir $(realpath results) \
    --keep-existing \
    "$@" \
    |& tee "$(basename $0).log"
