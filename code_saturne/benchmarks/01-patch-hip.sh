#!/usr/bin/env bash
#
# The test patches, plus what code_saturne 9.2's native HIP port needs to build
# and run correctly. Upstream's HIP backend doesn't work as shipped; the CUDA
# backend that SCALE compiles needs none of these.
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

apply_patch() {
    patch -p1 -d code_saturne <"${SCRIPT_DIR}/patches/$1.patch"
}

bash "${SCRIPT_DIR}/../01-patch.sh"

# Build fixes: cub::SyncStream -> hipStreamSynchronize, a missing rocprim
# include, extern "C" definitions that didn't match their C++ declarations, and
# a stream() accessor on the HIP dispatch context.
apply_patch hip_9.2_build_fixes

# Outdated cs_hip_get_stream / cs_blas_hip_dot signatures; float gradients fall
# back to the generic code, as the HIP kernels only exist for double; and lane
# masks widened for 64-thread wavefronts. The code used 32-bit masks
# (1u << lane, -1u), which is undefined for lanes 32-63 and silently breaks
# match-any and segmented reductions.
apply_patch hip_9.2_build_fixes_2

# count_to_index's HIP branch was an unimplemented TODO that fell back to an
# unsynchronised host scan, leaving c_f_row_ids null and faulting the GPU in
# multigrid coarsening. Call the rocPRIM scan instead.
apply_patch hip_9.2_count_to_index

# cs_halo_sync_pack_d had no HIP branch, so halo exchanges sent an unpacked
# device buffer over MPI.
apply_patch hip_9.2_halo_pack_d

# The same driver workaround SCALE's build gets; see 01-patch-scale.sh.
apply_patch hip_9.2_no_svm_hints
