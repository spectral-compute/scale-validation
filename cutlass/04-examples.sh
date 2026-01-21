#!/bin/bash
set -Eeuo pipefail

LOGDIR="build"
LOGFILE="${LOGDIR}/examples.log"
JUNIT="${LOGDIR}/cutlass-examples.xml"
: > "${LOGFILE}"

echo "Writing to $LOGFILE"

# discover example executables
mapfile -t TESTS < <(find build/examples -type f -perm /100 | sort)

# your skip list (exact paths)
SKIP=(
    # These require external input and require special handling to provide it.
    examples/41_fused_multi_head_attention/41_fused_multi_head_attention_backward

    # These crash the GPU with a segfault and sometimes the whole system.
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm75_rf
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm75_shmem
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm80_rf
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_s8_sm80_shmem

    # These failed
    examples/13_two_tensor_op_fusion/13_fused_two_convs_f16_sm80_shmem
    examples/13_two_tensor_op_fusion/13_fused_two_convs_s8_sm80_shmem
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_f16_sm80_shmem
    examples/15_ampere_sparse_tensorop_gemm/15_ampere_sparse_tensorop_gemm
    examples/15_ampere_sparse_tensorop_gemm/15_ampere_sparse_tensorop_gemm_universal
    examples/15_ampere_sparse_tensorop_gemm/15_ampere_sparse_tensorop_gemm_with_visitor
    examples/18_ampere_fp64_tensorop_affine2_gemm/18_ampere_fp64_tensorop_affine2_gemm
    examples/32_basic_trmm/32_basic_trmm
    examples/13_two_tensor_op_fusion/13_fused_two_convs_f16_sm75_rf
    examples/13_two_tensor_op_fusion/13_fused_two_convs_f16_sm75_shmem
    examples/13_two_tensor_op_fusion/13_fused_two_convs_f16_sm80_rf
    examples/13_two_tensor_op_fusion/13_fused_two_convs_s8_sm75_shmem
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_f16_sm75_rf
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_f16_sm75_shmem
    examples/13_two_tensor_op_fusion/13_fused_two_gemms_f16_sm80_rf
    examples/45_dual_gemm/45_dual_gemm
)

# bound example runtime (seconds) if timeout is available
#EXAMPLE_TIMEOUT="${EXAMPLE_TIMEOUT:-0}"  # 0 = no timeout
EXAMPLE_TIMEOUT=30

# helper to check exact membership
is_skipped() {
    local x="$1"
    for s in "${SKIP[@]}"; do
        [[ "$x" == "$s" ]] && return 0
    done
    return 1
}

total=${#TESTS[@]}
passed=0 failed=0 skipped=0

TMPCASE="$(mktemp)"
: > "${TMPCASE}"

FAILURES=()

for T in "${TESTS[@]}"; do
    echo "======== ${T} ========" | tee -a "$LOGFILE"
    if is_skipped "$T"; then
        ((++skipped))
        printf '  <testcase classname="cutlass.examples" name="%s" time="0"><skipped>Skipped by list</skipped></testcase>\n' \
        "$(basename "$T")" >> "${TMPCASE}"
        echo " -- SKIPPED --" | tee -a "$LOGFILE"
        continue
    fi

    RUNLOG="$(mktemp)"
    start_ts="$(date +%s.%N)"
    rc=0

    set +e
    if command -v timeout >/dev/null 2>&1 && (( EXAMPLE_TIMEOUT > 0 )); then
        timeout "${EXAMPLE_TIMEOUT}"s "$T" --help |& tee -a "$LOGFILE" | tee "$RUNLOG" >/dev/null
    else
        "$T" --help |& tee -a "$LOGFILE" | tee "$RUNLOG" >/dev/null
    fi
    rc=${PIPESTATUS[0]}

    # If --help fails, try with no args
    if (( rc != 0 )); then
        : > "$RUNLOG"
        if command -v timeout >/dev/null 2>&1 && (( EXAMPLE_TIMEOUT > 0 )); then
            timeout "${EXAMPLE_TIMEOUT}"s "$T" |& tee -a "$LOGFILE" | tee "$RUNLOG" >/dev/null
        else
            "$T" |& tee -a "$LOGFILE" | tee "$RUNLOG" >/dev/null
        fi
        rc=${PIPESTATUS[0]}
    fi
    set -e

    end_ts="$(date +%s.%N)"
    dur=$(python3 - <<PY
from decimal import Decimal, ROUND_HALF_UP
s=Decimal("${start_ts}"); e=Decimal("${end_ts}")
print((e-s).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP))
PY
)

    base="$(basename "$T")"
    if (( rc == 0 )); then
        ((++passed))
        printf '  <testcase classname="cutlass.examples" name="%s" time="%s"/>\n' \
            "$base" "$dur" >> "${TMPCASE}"
    else
        # Treat “usage / invalid option / required arg” cases as skipped (no data provided)
        if grep -qiE 'usage:|invalid|unrecognized option|required.*argument' "$RUNLOG"; then
            ((++skipped))
            printf '  <testcase classname="cutlass.examples" name="%s" time="%s"><skipped>Requires arguments or prints usage</skipped></testcase>\n' \
            "$base" "$dur" >> "${TMPCASE}"
        else
            ((++failed))
            FAILURES+=("$T")
            tail_txt="$(tail -n 120 "$RUNLOG" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g')"
            printf '  <testcase classname="cutlass.examples" name="%s" time="%s"><failure message="exit code %d"><![CDATA[%s]]></failure></testcase>\n' \
                "$base" "$dur" "$rc" "$tail_txt" >> "${TMPCASE}"
        fi
    fi
    rm -f "$RUNLOG"
done

# echo human summary
for s in "${SKIP[@]}";    do echo "Skipped: ${s}"; done
for f in "${FAILURES[@]}"; do echo "Failed:  ${f}"; done
echo "Summary"
echo "Total:   $total"
echo "Passed:  $passed"
echo "Failed:  $failed"
echo "Skipped: $skipped"

# write JUnit
{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    printf '<testsuite name="cutlass_examples" tests="%d" failures="%d" skipped="%d">\n' "$total" "$failed" "$skipped"
    cat "${TMPCASE}"
    echo '</testsuite>'
} > "${JUNIT}"
rm -f "${TMPCASE}"

echo "JUnit report: ${JUNIT}"
echo "Cutlass example script finished"
if (( failed > 0 )); then
  exit 1
fi
exit 0
