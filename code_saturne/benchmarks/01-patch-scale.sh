#!/usr/bin/env bash
#
# The test patches, plus a workaround for the amdgpu driver's managed-memory
# hints, which the HIP benchmark build gets too (see 01-patch-hip.sh).
#
# cuda_9.2_no_svm_hints stubs out cs_mem_cuda_priv's prefetch and read-mostly
# wrappers and the solver's _prefetch_h2d, so managed memory migrates on XNACK
# page faults rather than up front. On AMD, cudaMemPrefetchAsync/cudaMemAdvise
# go through the KFD SVM interface (hsaKmtSVMSetAttr), which is broken on the
# drivers tried so far:
#
#   amdgpu 6.16.13  multi-rank prefetch oopses in svm_range_set_attr, and the
#                   machine needs a reboot.
#   amdgpu 7.1.9    prefetch with XNACK corrupts data: results diverge, where
#                   the same build was bit-exact on 6.16.13.
#
# With the hints gone, XNACK runs on 1 and 2 GPUs are bit-exact against
# non-XNACK ones. Only SCALE gets this: NVIDIA's driver doesn't have the bug.
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

bash "${SCRIPT_DIR}/../01-patch.sh"

patch -p1 -d code_saturne <"${SCRIPT_DIR}/patches/cuda_9.2_no_svm_hints.patch"
