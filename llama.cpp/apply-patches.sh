#!/bin/bash
# Applies every SCALE/gfx90a compatibility patch to $LLAMA_DIR and VERIFIES each one actually
# landed on disk -- not just that the patch tool exited 0.
#
# Design notes from hard-won experience, not hypothetical:
#   1. `git apply` silently printed "Skipped patch '...'" for one file (deciding, wrongly, that
#      it didn't need the change) while still exiting 0, so the script reported overall success
#      with the change never having landed. Fixed by switching to plain `patch -p1`.
#   2. Plain `patch -p1` hard-FAILED a hunk on a file that, on inspection, already had the
#      intended end-state applied from an earlier run. Fixed by checking the target state BEFORE
#      applying and skipping cleanly if it's already correct.
#   3. Globally fixing ggml_cuda_get_physical_warp_size() (an earlier attempt, since reverted)
#      correctly made it report 64 for gfx90a -- but broke unrelated code in fattn-mma-f16.cuh
#      (cp_async assumes a hardcoded 32-lane MMA operand group, unrelated to physical wavefront
#      width) and mmf.cuh (rows_per_block tuning constants assume 32-wide warps throughout the
#      rest of ggml-cuda's dispatch logic, which is still implicitly coupled to GGML_USE_HIP).
#      Fixing that properly means auditing every warp-size-dependent tuning decision in the
#      codebase, which is out of scope here. Instead: leave ggml_cuda_get_physical_warp_size()
#      alone (still wrong, but consistently so, matching what the rest of the file assumes) and
#      patch ONLY the specific host-side call sites proven to need the real hardware value to
#      match what their own kernel's __launch_bounds__ actually compiled to (fwht.cu, mmvq.cu).
#
# Every patch below is checked BEFORE applying (skip cleanly if the target state already holds --
# makes re-running this script on a partially-patched tree safe) and AFTER applying (abort loudly
# with the exact missing/still-present marker if the state still isn't right -- no more trusting
# the tool's exit code or "Skipped"/"already applied" messages as the truth).
set -e

SCRIPT_DIR="$(realpath "$(dirname "$PWD")")"
LLAMA_DIR="${LLAMA_DIR:-llama.cpp-b10144}"
PATCH_ARCHIVE="${SCRIPT_DIR}/llama-patches.tar.gz"
PATCH_DIR="${SCRIPT_DIR}/patches"

mkdir -p "$PATCH_DIR"
tar -xf "$PATCH_ARCHIVE" -C "$PATCH_DIR"

if [ ! -d "$LLAMA_DIR" ]; then
    echo "FATAL: LLAMA_DIR '$LLAMA_DIR' does not exist (cwd: $(pwd))." >&2
    exit 1
fi

REQUIRED_PATCHES=(
    mmf-warp-sync.patch
    fp4-scale-decode.patch
    fattn-shared-mem-fallback.patch
    disable-cooperative-launch.patch
    disable-cub.patch
    fwht-warp-size.patch
    mmvq-warp-size.patch
)
missing=0
for p in "${REQUIRED_PATCHES[@]}"; do
    if [ ! -f "${PATCH_DIR}/${p}" ]; then
        echo "FATAL: missing ${PATCH_DIR}/${p}" >&2
        missing=1
    fi
done
if [ "$missing" -ne 0 ]; then
    echo "fwht-warp-size.patch and mmvq-warp-size.patch aren't in llama-patches.tar.gz --" >&2
    echo "drop them into ${PATCH_DIR} once and they'll survive future tar re-extractions." >&2
    echo "If physical-warp-size.patch is still in ${PATCH_DIR}, it's obsolete -- delete it," >&2
    echo "and make sure it's reverted from ${LLAMA_DIR} (see conversation notes)." >&2
    exit 1
fi

# all_checks_pass <mode> <file> <marker> [<mode> <file> <marker> ...]
#   mode is "contains" or "absent". file is relative to $LLAMA_DIR. Returns 0 only if every
# triple's condition holds against the file currently on disk -- this is the actual source of
# truth for "is this patch's change present," independent of what any patch tool reports.
all_checks_pass() {
    while [ "$#" -ge 3 ]; do
        local mode="$1" file="$2" marker="$3"
        shift 3
        case "$mode" in
            contains)
                grep -qF -- "$marker" "${LLAMA_DIR}/${file}" || return 1
                ;;
            absent)
                grep -qF -- "$marker" "${LLAMA_DIR}/${file}" && return 1
                ;;
            *)
                echo "FATAL: bad mode '$mode' in all_checks_pass (script bug)" >&2
                exit 1
                ;;
        esac
    done
    return 0
}

# apply_and_verify <patch-file> <mode> <file> <marker> [...]
#   Skips applying if the target state already holds (idempotent, safe to re-run). Otherwise
# applies via plain `patch` (not `git apply` -- see header) and re-checks afterward. Any
# discrepancy aborts the whole script immediately with the exact file/marker that didn't match,
# rather than letting a partially-patched tree get built and tested.
apply_and_verify() {
    local patch_file="$1"
    shift
    if all_checks_pass "$@"; then
        echo "==> $(basename "$patch_file"): expected state already present, skipping"
        return 0
    fi
    echo "==> Applying $(basename "$patch_file")"
    if ! patch -p1 -d "$LLAMA_DIR" --forward --no-backup-if-mismatch < "$patch_file"; then
        echo "FATAL: patch failed to apply $(basename "$patch_file"), and the target state was" >&2
        echo "       not already present beforehand. Check ${LLAMA_DIR}/*.rej for the exact" >&2
        echo "       conflicting hunk -- this needs a human look, not another blind retry." >&2
        exit 1
    fi
    if ! all_checks_pass "$@"; then
        echo "FATAL: $(basename "$patch_file") reported success but the expected change is" >&2
        echo "       still not present on disk. Do not trust this -- something is wrong." >&2
        exit 1
    fi
    echo "    verified"
}

# 1. Add the __syncwarp() the CUDA model requires in the f32 tensor-core matmul kernels (mul_mat_f /
#    mul_mat_f_ids) and the MoE id-compaction helper (mm_ids_helper), which exchange data across warp
#    lanes through shared memory (warp-lockstep execution is not guaranteed).
apply_and_verify "${PATCH_DIR}/mmf-warp-sync.patch" \
    contains ggml/src/ggml-cuda/mmf.cuh "__syncwarp();" \
    contains ggml/src/ggml-cuda/mmid.cu "__syncwarp();"

# 2. Decode the MXFP4 (E8M0) and NVFP4 (UE4M3) block scales via the portable software path, so the
#    dequantized values are bit-identical to the CPU reference on every target.
apply_and_verify "${PATCH_DIR}/fp4-scale-decode.patch" \
    absent ggml/src/ggml-cuda/common.cuh "__nv_cvt_e8m0_to_bf16raw"

# 3. Flash attention: when an MMA config needs more shared memory than the device provides, fall back
#    to the shared-memory-frugal tile kernel. The check is device-adaptive (actual requirement vs the
#    device's actual limit), so it adapts to targets with differing shared-memory sizes.
apply_and_verify "${PATCH_DIR}/fattn-shared-mem-fallback.patch" \
    contains ggml/src/ggml-cuda/fattn-mma-f16.cuh "ggml_cuda_flash_attn_ext_tile(ctx, dst);"

# 4. Use the single-block soft-max reduction (the only consumer of cooperative launch) by reporting
#    cooperative launch as unsupported.
apply_and_verify "${PATCH_DIR}/disable-cooperative-launch.patch" \
    absent ggml/src/ggml-cuda/ggml-cuda.cu "cudaDevAttrCooperativeLaunch"

# 5. Build without NVIDIA's device-level CUB algorithms (cub::DeviceReduce, cub::DeviceRadixSort,
#    cub::DeviceScan, cub::DeviceTopK); the affected ops use llama.cpp's native kernels (bitonic
#    argsort, sum-rows reduction, native scan), as upstream does for non-NVIDIA backends.
apply_and_verify "${PATCH_DIR}/disable-cub.patch" \
    absent ggml/src/ggml-cuda/common.cuh "define GGML_CUDA_USE_CUB"

# 6. ggml_cuda_op_fwht sized its launch from the real (64-wide) runtime warp size while fwht_cuda's
#    __launch_bounds__ was compiled against ggml_cuda_get_physical_warp_size(), which returns 32
#    under SCALE (GGML_USE_HIP is never defined here, even though __GFX9__ correctly is). That
#    host/device mismatch trips cudaErrorInvalidValue at launch. Match the host side to the
#    kernel's compile-time assumption instead of the real hardware value.
apply_and_verify "${PATCH_DIR}/fwht-warp-size.patch" \
    contains ggml/src/ggml-cuda/fwht.cu "kernel's compile-time assumption here instead of querying the real hardware value."

# 7. Same failure mode as patch 6, in mul_mat_vec_q_moe_launch's block_dims (mmvq.cu): the host
#    side was querying the real 64-wide warp size while the kernel's __launch_bounds__ compiled
#    against 32. Match the host side to the kernel's compile-time assumption here too.
apply_and_verify "${PATCH_DIR}/mmvq-warp-size.patch" \
    contains ggml/src/ggml-cuda/mmvq.cu "mul_mat_vec_q_moe's __launch_bounds__ is get_mmvq_mmid_max_batch_for_device"

echo
echo "All 7 patches confirmed present in $LLAMA_DIR (applied fresh or already there -- either way, verified against actual file content, not tool exit codes)."
