#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/cutlass/build"

TESTS=(
    $(find examples -type f -perm /100 | sort)
)
SKIP=(
    # These require external input and require special handling to provide it.
    examples/41_fused_multi_head_attention/41_fused_multi_head_attention_backward

    # These crash the GPU with a segfault and sometimes the whole system.
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm75_rf
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm75_shmem
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm80_rf
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm80_shmem
)

set +e
FAILURES=()
for T in "${TESTS[@]}" ; do
    echo "======== ${T} ========"
    if [[ " ${SKIP[@]} " =~ " ${T} " ]]; then
        echo " -- SKIPPED --"
        continue
    fi

    "${T}"
    if [ "$?" != "0" ] ; then
        FAILURES+=("${T}")
    fi
done
set -e

for T in "${SKIP[@]}" ; do
    echo "Skipped: ${T}"
done
for T in "${FAILURES[@]}" ; do
    echo "Failed: ${T}"
done
if [ ! -z "${FAILURES}" ] ; then
    exit 1
fi
