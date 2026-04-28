#!/bin/bash
set -u

OUT_DIR="$(realpath .)/HeCBench"
BUILD_DIR="${OUT_DIR}/build/cuda-sm${CUDAARCHS}"
BIN_DIR="${BUILD_DIR}/bin/cuda"

LOGFILE="$BUILD_DIR/hecbench-run.log"
NUMBERSFILE="$BUILD_DIR/hecbench-numbers.txt"
XMLFILE="$BUILD_DIR/hecbench-run.xml"
TMPXML="$BUILD_DIR/.tmp_cases.xml"

: > "$LOGFILE"
: > "$NUMBERSFILE"
: > "$TMPXML"

passed=0
failed=0
skipped=5

# Skip cm-cuda, divergence, mdh, ising since it seems to run forever
echo '  <testcase classname="hecbench" name="src/cm-cuda" time="0"><skipped>Skipped by script</skipped></testcase>' >> "$TMPXML"
echo '  <testcase classname="hecbench" name="src/divergence-cuda" time="0"><skipped>Skipped by script</skipped></testcase>' >> "$TMPXML"
echo '  <testcase classname="hecbench" name="src/mdh-cuda" time="0"><skipped>Skipped by script</skipped></testcase>' >> "$TMPXML"
echo '  <testcase classname="hecbench" name="src/ising-cuda" time="0"><skipped>Skipped by script</skipped></testcase>' >> "$TMPXML"
echo '  <testcase classname="hecbench" name="src/laplace-cuda" time="0"><skipped>Skipped by script</skipped></testcase>' >> "$TMPXML"

for exe in $(find "$BIN_DIR" -mindepth 1 -maxdepth 1 -type f -executable \
  ! -name "cm" ! -name "divergence" ! -name "mdh" ! -name "ising" ! -name "laplace" | sort); do
  name="${exe#${OUT_DIR}/}"
  runlog=$(mktemp)

  echo "Executing $name" | tee -a "$LOGFILE"

  start=$(date +%s)

  if "$exe" > "$runlog" 2>&1; then
    passed=$((passed + 1))
    status="passed"
  else
    failed=$((failed + 1))
    status="failed"
  fi

  end=$(date +%s)
  runtime=$((end - start))

  cat "$runlog" >> "$LOGFILE"

  echo "======== $name ========" >> "$NUMBERSFILE"
  grep -E '[0-9]' "$runlog" >> "$NUMBERSFILE" || true
  echo >> "$NUMBERSFILE"

  if [ "$status" = "passed" ]; then
    echo "  <testcase classname=\"hecbench\" name=\"$name\" time=\"$runtime\"/>" >> "$TMPXML"
  else
    echo "  <testcase classname=\"hecbench\" name=\"$name\" time=\"$runtime\"><failure message=\"run failed\"/></testcase>" >> "$TMPXML"
  fi

  rm -f "$runlog"
done

total=$((passed + failed + skipped))

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo "<testsuite name=\"hecbench\" tests=\"$total\" failures=\"$failed\" skipped=\"$skipped\">"
  cat "$TMPXML"
  echo "</testsuite>"
} > "$XMLFILE"

rm -f "$TMPXML"

echo "Summary"
echo "Passed : $passed"
echo "Failed : $failed"
echo "Skipped: $skipped"
echo "Log file: $LOGFILE"
echo "Numbers file: $NUMBERSFILE"
echo "XML file: $XMLFILE"

if [ "$failed" -gt 0 ]; then
  exit 1
fi
