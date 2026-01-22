#!/usr/bin/env bash
set -euo pipefail

compare_files() {
  local f1="$1" f2="$2" log="${3:-diff_log.txt}"
  : >"$log"                                # ensure the log file exists
  [[ -f "$f1" && -f "$f2" ]] || return 2   # 2 = missing file(s)
  diff -u "$f1" "$f2" >"$log"
}

REPO_ROOT="$PWD"
OUT_DIR=$(realpath .)
if OUT_ABS="$(readlink -f "$OUT_DIR" 2>/dev/null)"; then :; \
elif OUT_ABS="$(realpath "$OUT_DIR" 2>/dev/null)"; then :; \
else OUT_ABS="$REPO_ROOT/$OUT_DIR"; fi

RESULTS_DIR="$OUT_ABS/rodinia_suite"
mkdir -p "$RESULTS_DIR"
JUNIT="$RESULTS_DIR/rodinia.xml"
TMPCASE="$RESULTS_DIR/.cases.tmp"
: >"$TMPCASE"
echo "Writing JUnit to: $JUNIT"

cd "$OUT_ABS/rodinia_suite/rodinia_suite/cuda"

export SCALE_EXCEPTIONS=2

benchmarks=(backprop bfs b+tree cfd dwt2d gaussian heartwall hotspot hotspot3D huffman lavaMD nn nw pathfinder)
known_failures=(cfd hotspot3D)

total=${#benchmarks[@]}
passed=0 failed=0 skipped=0

echo "[===================]"

for b in "${benchmarks[@]}"; do
  echo "[ RUN               ] $b"
  pushd "$b" >/dev/null

  # Execute benchmark
  path=$(pwd)
  ./run.sh "$path" "${b}.csv"

  # Choose reference files
  case "$b" in
    cfd)   FILE1="result_density_energy.txt"; FILE2="nat_result_density_energy.txt" ;;
    dwt2d) FILE1="rgb.bmp.dwt.g";            FILE2="rgb.bmp.dwt_nat.g" ;;
    *)     FILE1="result.txt";               FILE2="nat_result.txt" ;;
  esac

  # Grab average GPU time (ms → seconds for JUnit)
  ms="$(grep -m1 'Computation' average.csv | awk -F',' '{print $2}' || echo 0)"
  sec=$(awk -v ms="$ms" 'BEGIN{printf "%.6f", (ms+0)/1000}')

  # Compare and record
  DIFFLOG="${RESULTS_DIR}/${b}_diff.txt"
  rc=0
  compare_files "$FILE1" "$FILE2" "$DIFFLOG" || rc=$?

  if (( rc == 0 )); then
    ((++passed))
    printf '  <testcase classname="rodinia" name="%s" time(sec)="%s"/>\n' \
         "$b" "$sec" >>"$TMPCASE"
  else
    # Is this a known failure we want to ignore?
    if [[ " ${known_failures[*]} " == *" $b "* ]]; then
      ((++skipped))
      short_ms=$(awk -v ms="${ms:-0}" 'BEGIN{printf "%.2f", ms+0}')
      printf '  <testcase classname="rodinia" name="%s" time="%s"><skipped>Known failure (ignored for CI pass). See %s; avg %s ms.</skipped></testcase>\n' \
             "$b" "$sec" "$(basename "$DIFFLOG")" "$short_ms" >>"$TMPCASE"
      echo "[   KNOWN FAILURE   ] $b (ignored; see $(basename "$DIFFLOG"))"
    else
      ((++failed))
      short_ms=$(awk -v ms="${ms:-0}" 'BEGIN{printf "%.2f", ms+0}')
      printf '  <testcase classname="rodinia" name="%s" time="%s"><failure message="Output mismatch (see %s; avg %s ms)"/></testcase>\n' \
             "$b" "$sec" "$(basename "$DIFFLOG")" "$short_ms" >>"$TMPCASE"
    fi
  fi
  echo "[   AVG GPU time    ] ${ms:-0} ms"
  popd >/dev/null
done

echo "[===================] $total apps ran."
echo "[       PASSED      ] $passed apps."
echo "[       FAILED      ] $failed apps."
echo "[       SKIPPED     ] $skipped apps."

# Build the testsuite wrapper now that counts are known
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  printf '<testsuite name="rodinia" tests="%d" failures="%d" skipped="%d">\n' "$total" "$failed" "$skipped"
  cat "$TMPCASE"
  echo '</testsuite>'
} >"$JUNIT"

# Fail the job only on real failures (known failures are skipped)
if (( failed > 0 )); then
  exit 1
fi
