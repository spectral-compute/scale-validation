#!/bin/bash

set -o errtrace
set -o functrace
set -o nounset

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/cutlass/build"

LOGFILE="${OUT_DIR}/cutlass/build/tests.log"

echo "Writing to $LOGFILE"
rm -f "$LOGFILE"

FILTERS='*:-'

# These tests require > 64k of smem to execute
# e.g. with export SCALE_EXCEPTIONS=2, report "failed due to smem_size"
for LargeSMEM in \
    SM80_CuTe_Ampere.CooperativeGemm2_Double_MMA \
    SM80_CuTe_Ampere.CooperativeGemm3_Half_MMA_CustomSmemLayouts \
    SM80_CuTe_Ampere.CooperativeGemm4_Half_MMA_SwizzledSmemLayouts \
    SM80_CuTe_Ampere.CooperativeGemm5_Double_MMA_SwizzledSmemLayouts \
    SM80_CuTe_Ampere.CooperativeGemmComposedStride \
    SM80_Device_Gemm_f64n_f64n_f64n_simt_f64.128x128x64_64x64x64 \
    SM80_Device_Gemm_f64n_f64t_f64n_simt_f64.128x128x64_64x64x64 \
    SM80_Device_Gemm_f64n_f64t_f64n_tensor_op_f64.128x128x64_64x64x64 \
    SM80_Device_Gemm_f64t_f64n_f64n_simt_f64.128x128x64_64x64x64 \
    SM80_Device_Gemm_f64t_f64n_f64n_tensor_op_f64.128x128x64_64x64x64 \
    SM80_Device_Gemm_f64t_f64t_f64n_simt_f64.128x128x64_64x64x64 \
    SM80_Device_Gemm_tf32n_tf32n_f32n_tensor_op_f32.128x128x32_64x64x64 \
    SM80_Device_Gemm_tf32n_tf32t_f32n_tensor_op_f32.128x128x32_64x64x64 \
    SM80_Device_Gemm_tf32t_tf32n_f32n_tensor_op_f32.128x128x32_64x64x64 \
    SM80_Device_Gemm_tf32t_tf32n_f32n_tensor_op_f32.128x128x32_64x64x64_profiling \
    SM80_Device_Gemm_tf32t_tf32t_f32n_tensor_op_f32.128x128x32_64x64x64
do    
    FILTERS="$FILTERS:$LargeSMEM"
done

TESTS=(
    $(find test -type f -executable | sort)
)

# Currently this runs every test under the same negative filter list.
FAILURES=()
for T in "${TESTS[@]}" ; do
    echo "======== ${T} ========" | tee -a $LOGFILE
    "${T}" --gtest_filter=$FILTERS |& tee -a $LOGFILE
    if [ "$?" != "0" ] ; then
        FAILURES+=("${T}")
    fi
done

for T in "${FAILURES[@]}" ; do
    echo "Failed: ${T}"
done


echo "Summary"
# todo, might want to emit json / xml or similar instead of hacking it out with grep
grep '\[  PASSED  \] [0-9]* tests[.]' "$LOGFILE" | cut -d ' ' -f 6 | paste -sd+ | bc
grep '\[  FAILED  \] [0-9]* tests, listed below:' "$LOGFILE" | cut -d ' ' -f 6 | paste -sd+ | bc


echo "Cutlass test script finished"

if [ ! -z "${FAILURES}" ] ; then
    exit 1
fi

exit 0
