#!/bin/bash

set -ETeuo pipefail

LOGFILE="examples.log"
echo "Writing to $LOGFILE"
rm -f "$LOGFILE"

TESTS=(
    $(find build/examples -type f -perm /100 | sort)
)
SKIP=(
    # These require external input and require special handling to provide it.
    build/examples/41_fused_multi_head_attention/41_fused_multi_head_attention_backward

    # These crash the GPU (on gfx1100) with a segfault and sometimes the whole system.
    build/examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm75_rf
    build/examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm75_shmem
    build/examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm80_rf
    build/examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm80_shmem

    # These failed (on gfx1100).
    build/examples/13_two_tensor_op_fusion/13_fused_two_convs_f16_sm80_shmem
    build/examples/13_two_tensor_op_fusion/13_fused_two_convs_s8_sm80_shmem
    build/examples/13_two_tensor_op_fusion/13_fused_two_gemms_f16_sm80_shmem
    build/examples/13_two_tensor_op_fusion/13_fused_two_gemms_grouped_f16_sm80_rf
    build/examples/14_ampere_tf32_tensorop_gemm/14_ampere_tf32_tensorop_gemm
    build/examples/15_ampere_sparse_tensorop_gemm/15_ampere_sparse_tensorop_gemm
    build/examples/15_ampere_sparse_tensorop_gemm/15_ampere_sparse_tensorop_gemm_universal
    build/examples/15_ampere_sparse_tensorop_gemm/15_ampere_sparse_tensorop_gemm_with_visitor
    build/examples/16_ampere_tensorop_conv2dfprop/16_ampere_tensorop_conv2dfprop
    build/examples/18_ampere_fp64_tensorop_affine2_gemm/18_ampere_fp64_tensorop_affine2_gemm
    build/examples/25_ampere_fprop_mainloop_fusion/25_ampere_3d_fprop_mainloop_fusion
    build/examples/25_ampere_fprop_mainloop_fusion/25_ampere_fprop_mainloop_fusion
    build/examples/32_basic_trmm/32_basic_trmm
    build/examples/36_gather_scatter_fusion/36_gather_scatter_fusion
    build/examples/37_gemm_layernorm_gemm_fusion/37_gemm_layernorm_gemm_fusion
    build/examples/59_ampere_gather_scatter_conv/59_ampere_gather_scatter_conv

    # These failed on gfx1030.
    build/examples/19_tensorop_canonical/19_tensorop_canonical
)

set +e
FAILURES=()
for T in "${TESTS[@]}" ; do
    echo "======== ${T} ========" | tee -a "${LOGFILE}"
    if [[ " ${SKIP[@]} " =~ " ${T} " ]]; then
        echo " -- SKIPPED --" | tee -a "${LOGFILE}"
        continue
    fi

    "${T}" |& tee -a "${LOGFILE}"
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
if [ "${#FAILURES[@]}" != "0" ] ; then
    exit 1
fi
