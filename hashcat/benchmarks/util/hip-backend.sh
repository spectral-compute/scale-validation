# shellcheck shell=bash
# shellcheck disable=SC2034 # used by the scripts that source this
# Sourced by the -hip benchmarks: picks which of ROCm's native backends hashcat
# uses, instead of its CUDA one. Same binary: hashcat picks the backend at
# runtime.
#
# hashcat's HIP backend can't build its kernels with ROCm 7.2's hipRTC (the
# device libraries aren't linked: "undefined hidden symbol:
# __ockl_get_group_id"), so use ROCm's OpenCL runtime then.
#
# Sets HASHCAT_BACKEND (hip or opencl) and HASHCAT_BACKEND_ARGS.
if ./build/hashcat --backend-ignore-cuda --backend-ignore-opencl -m 1400 -b \
    >/dev/null 2>&1; then
    HASHCAT_BACKEND=hip
    HASHCAT_BACKEND_ARGS=(--backend-ignore-cuda --backend-ignore-opencl)
else
    log "hashcat's HIP backend doesn't work here; using ROCm's OpenCL"
    HASHCAT_BACKEND=opencl
    HASHCAT_BACKEND_ARGS=(--backend-ignore-cuda --backend-ignore-hip)
fi
