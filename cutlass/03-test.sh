#!/bin/bash

set -o errtrace
set -o functrace
set -o nounset
set -o pipefail

LOGFILE="build/tests.log"
JUNIT="build/cutlass-tests.xml"

# If You want to limit the Tests executing specify TEST_LIMIT (0 = no limit).
# TEST_LIMIT="${TEST_LIMIT:-5}"
TEST_LIMIT="${TEST_LIMIT:-0}"

# Debug mode: if 1, do NOT run tests—just parse the existing $LOGFILE
# to use it just add: DEBUG_USE_LOG=1 before ./test.sh
DEBUG_USE_LOG="${DEBUG_USE_LOG:-0}"

echo "Writing to $LOGFILE"
if [[ "$DEBUG_USE_LOG" != "1" ]]; then
  rm -f "$LOGFILE"
fi

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
    SM80_Device_Gemm_tf32t_tf32t_f32n_tensor_op_f32.128x128x32_64x64x64 \
    SM89_CuTe_Ada.CooperativeGemm_e4m3e4m3f32_MMA  \
    SM89_CuTe_Ada.CooperativeGemm_e4m3e5m2f32_MMA \
    SM89_CuTe_Ada.CooperativeGemm_e5m2e4m3f32_MMA \
    SM89_CuTe_Ada.CooperativeGemm_e5m2e5m2f32_MMA \
    SM80_Device_Conv2d_Fprop_Analytic_ImplicitGemm_tf32nhwc_tf32nhwc_f32nhwc_tensor_op_f32.128x128_32x3_64x64x32 \
    SM80_Device_Conv2d_Fprop_Optimized_ImplicitGemm_tf32nhwc_tf32nhwc_f32nhwc_tensor_op_f32_align2.128x128_32x3_64x64x32 \
    SM80_Device_Conv2d_Dgrad_Analytic_ImplicitGemm_tf32nhwc_tf32nhwc_f32nhwc_tensor_op_f32.128x128_32x3_64x64x32 \
    SM80_Device_Conv2d_Dgrad_Optimized_ImplicitGemm_tf32nhwc_tf32nhwc_f32nhwc_tensor_op_f32.128x128_32x3_64x64x32 \
    SM80_Device_Conv2d_Wgrad_Optimized_ImplicitGemm_tf32nhwc_tf32nhwc_f32nhwc_tensor_op_f32.128x128_32x3_64x64x32 \
    SM80_Device_Conv3d_Fprop_Analytic_ImplicitGemm_tf32ndhwc_tf32ndhwc_f32ndhwc_tensor_op_f32.128x128_32x3_64x64x32 \

do
    FILTERS="$FILTERS:$LargeSMEM"
done

TESTS=(
  $(find build/test -type f -executable \
      ! -name "*.so" ! -name "*.a" ! -name "*.o" | sort)
)

# -------------------------------------------------
# Run tests (unless DEBUG_USE_LOG=1)
# -------------------------------------------------
FAILURES=()
if [[ "$DEBUG_USE_LOG" != "1" ]]; then
  COUNTER=0
  for T in "${TESTS[@]}" ; do
      echo "======== ${T} ========" | tee -a "$LOGFILE"
      "${T}" --gtest_filter="$FILTERS" |& tee -a "$LOGFILE"
      rc=${PIPESTATUS[0]}
      if (( rc != 0 )); then
          FAILURES+=("${T}")
      fi
      # Limit the number of tests executing
      COUNTER=$((COUNTER + 1))
      #echo "COUNTER: ${COUNTER}"
      if [ "${TEST_LIMIT}" -gt 0 ] && [ "${COUNTER}" -ge "${TEST_LIMIT}" ]; then
          echo "Reached TEST_LIMIT=${TEST_LIMIT}; stopping early."
          break
      fi
  done

  for T in "${FAILURES[@]}" ; do
      echo "Failed: ${T}"
  done
else
  echo "DEBUG: Using pre-existing log at $LOGFILE; not running tests."
fi

# -------------------------------------------------
# JUnit XML creation (unchanged semantics)
#  - binary-aggregated by default; per-subtest if JUNIT_SUBTESTS=1
# -------------------------------------------------
{
    xml_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

    # Only binaries that actually ran (respects TEST_LIMIT) – requires the header lines in the log
    mapfile -t EXECUTED < <(grep -E '^======== ' "$LOGFILE" | sed -E 's/^======== (.+) ========$/\1/')

    # Map of binaries that returned nonzero (from your loop)

    declare -A FAILMAP=()
    if (( ${#FAILURES[@]} > 0 )); then
    for f in "${FAILURES[@]}"; do
        [[ -n "$f" ]] || continue
        FAILMAP["$f"]=1
    done
    fi


    tmpcases="$(mktemp)"; : >"$tmpcases"

    tests_total=0
    failures_total=0
    skipped_total=0

    for T in "${EXECUTED[@]}"; do
        base="$(basename "$T")"

        # Slice of the log belonging to this binary
        snippet="$(awk -v s="======== ${T} ========" '
        $0==s {flag=1; next}
        /^======== / && flag { exit }
        flag { print }
        ' "$LOGFILE")"

        # Parse global summary line for total ms and test count (if present)
        global_ms="$(printf '%s' "$snippet" \
                    | grep -E '^\[==========\].*\([0-9]+ ms total\)' \
                    | grep -Eo '\(([0-9]+) ms total\)' \
                    | grep -Eo '[0-9]+' \
                    | tail -n1)"
        tests_count="$(printf '%s' "$snippet" \
                        | grep -E '^\[==========\] [0-9]+ tests? from' \
                        | awk '{print $2}' \
                        | tail -n1)"

        # Fallbacks
        [[ -z "$global_ms" ]] && global_ms="$(printf '%s' "$snippet" \
                    | grep -Eo '\(([0-9]+) ms total\)' \
                    | grep -Eo '[0-9]+' \
                    | tail -n1)"
        [[ -z "$tests_count" ]] && tests_count=0

        sec=$(awk -v ms="${global_ms:-0}" 'BEGIN{printf "%.6f", (ms+0)/1000}')

        if [[ "${JUNIT_SUBTESTS:-0}" == "1" ]]; then
            # ----- Per-subtest mode -----
            while IFS=$'\t' read -r status name msec || [[ -n "$status" ]]; do
                [[ -z "$name" ]] && continue
                s=$(awk -v ms="${msec:-0}" 'BEGIN{printf "%.6f", (ms+0)/1000}')
                if [[ "$status" == "FAILED" ]]; then
                    failures_total=$((failures_total + 1))
                    tail_txt="$(printf '%s' "$snippet" | tail -n 120 | xml_escape)"
                    printf '  <testcase classname="cutlass.tests.%s" name="%s" time="%s"><failure message="failed subtest"><![CDATA[%s]]></failure></testcase>\n' \
                        "$base" "$name" "$s" "$tail_txt" >>"$tmpcases"
                elif [[ "$status" == "SKIPPED" ]]; then
                    skipped_total=$((skipped_total + 1))
                    printf '  <testcase classname="cutlass.tests.%s" name="%s" time="%s"><skipped/></testcase>\n' \
                        "$base" "$name" "$s" >>"$tmpcases"
                else
                    printf '  <testcase classname="cutlass.tests.%s" name="%s" time="%s"/>\n' \
                        "$base" "$name" "$s" >>"$tmpcases"
                fi
                tests_total=$((tests_total + 1))
            done < <(printf '%s\n' "$snippet" | awk '
                match($0, /^\[ *(OK|PASSED) *\] (.*) \(([0-9]+) ms\)$/, m) { printf("OK\t%s\t%s\n", m[2], m[3]); next }
                match($0, /^\[ *(OK|PASSED) *\] (.*)$/, m)                  { printf("OK\t%s\t0\n",  m[2]);       next }
                match($0, /^\[ *FAILED *\] (.*) \(([0-9]+) ms\)$/, m)       { printf("FAILED\t%s\t%s\n", m[1], m[2]); next }
                match($0, /^\[ *FAILED *\] (.*)$/, m)                       { printf("FAILED\t%s\t0\n",  m[1]);       next }
                match($0, /^\[ *SKIPPED *\] (.*) \(([0-9]+) ms\)$/, m)      { printf("SKIPPED\t%s\t%s\n", m[1], m[2]); next }
                match($0, /^\[ *SKIPPED *\] (.*)$/, m)                      { printf("SKIPPED\t%s\t0\n",  m[1]);       next }

            ')
         else
            # ----- Aggregated per-binary mode (default) -----
            failed_subtests=$(printf '%s\n' "$snippet" | grep -E '^\[ *FAILED *\] ' | wc -l)
            skipped_subtests=$(printf '%s\n' "$snippet" | grep -E '^\[ *SKIPPED *\] ' | wc -l)

            if [[ -n "${FAILMAP[$T]:-}" || "$failed_subtests" -gt 0 ]]; then
                failures_total=$((failures_total + 1))
                tail_txt="$(printf '%s' "$snippet" | tail -n 120 | xml_escape)"
                printf '  <testcase classname="cutlass.tests" name="%s" time="%s" tests="%s"><failure message="nonzero exit or failed subtests %s"><![CDATA[%s]]></failure></testcase>\n' \
                       "$base" "$sec" "$tests_count" "$failed_subtests" "$tail_txt" >>"$tmpcases"
            elif [[ "$skipped_subtests" -gt 0 ]]; then
                skipped_total=$((skipped_total + 1))
                printf '  <testcase classname="cutlass.tests" name="%s" time="%s" tests="%s"><skipped>contains %s skipped subtests</skipped></testcase>\n' \
                       "$base" "$sec" "$tests_count" "$skipped_subtests" >>"$tmpcases"
            else
                printf '  <testcase classname="cutlass.tests" name="%s" time="%s" tests="%s"/>\n' \
                       "$base" "$sec" "$tests_count" >>"$tmpcases"
            fi
            tests_total=$((tests_total + 1))
        fi
    done

    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        printf '<testsuite name="cutlass_tests" tests="%d" failures="%d" skipped="%d">\n' "$tests_total" "$failures_total" "$skipped_total"
        cat "$tmpcases"
        echo '</testsuite>'
    } > "$JUNIT"
    rm -f "$tmpcases"

    echo "JUnit report: $JUNIT"
}

# -------------------------------------------------
# FINAL SUMMARY (from tests.log: PASSED/FAILED/SKIPPED lines)
#   PASSED  = lines with "[  PASSED ]"
#   FAILED  = lines with "[  FAILED  ]"
#   SKIPPED = lines with "[  SKIPPED ]"
#   TOTAL   = lines with " ======= "
# -------------------------------------------------
echo "Summary (from $LOGFILE)"

_clean_log="$(sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g' "$LOGFILE" 2>/dev/null || true)"

failed=$(
  printf '%s\n' "$_clean_log" | grep -Eo '^\[ *FAILED *\] +[0-9]+' | awk '{sum += $NF} END{print sum+0}'
)

total_tests=$(
  printf '%s\n' "$_clean_log" | grep -E '^\[==========\] +[0-9]+ tests? from' | awk '{sum += $2} END{print sum+0}'
)

passed=$(
  printf '%s\n' "$_clean_log" | grep -Eo '^\[ *PASSED *\] +[0-9]+' | awk '{sum += $NF} END{print sum+0}'
)

skipped=$(
  printf '%s\n' "$_clean_log" | grep -Eo '^\[ *SKIPPED *\] +[0-9]+' | awk '{sum += $NF} END{print sum+0}'
)

#failed_derived=$(( total_tests - passed - skipped ))
#(( failed_derived < 0 )) && failed_derived=0

echo "  Total           : $total_tests ( / 3857)"
echo "  Passed          : $passed ( / 3566)"
echo "  Skipped         : $skipped ( / 33)"
#echo "  Failed (derived): $failed_derived
echo "  Failed   : $failed ( / 258)"

echo "Cutlass test script finished"

if (( ${#FAILURES[@]} > 547 )); then
  echo "Known failures are 547. If we have more exit 1!"
  exit 1
fi

exit 0
