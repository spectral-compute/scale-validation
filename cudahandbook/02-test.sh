#!/bin/bash

set -euo pipefail
pwd
BUILD_DIR="build"
LOGFILE="$BUILD_DIR/cudahandbook-run.log"
NUMBERSFILE="$BUILD_DIR/cudahandbook-numbers.txt"
XMLFILE="$BUILD_DIR/cudahandbook-run.xml"
TMPXML="$BUILD_DIR/.tmp_cases.xml"

: > "$LOGFILE"
: > "$NUMBERSFILE"
: > "$TMPXML"

passed=0
failed=0
skipped=0

# Exclude SMs and peer2peerTestNUMA benchmarks.
for exe in $(find "$BUILD_DIR/SMs" -mindepth 1 -maxdepth 1 -type f -executable | sort); do
  name="${exe#${BUILD_DIR}/}"
  echo "  <testcase classname=\"cudahandbook\" name=\"$name\" time=\"0\"><skipped>Skipped by script</skipped></testcase>" >> "$TMPXML"
  skipped=$((skipped + 1))
done

echo '  <testcase classname="cudahandbook" name="memory/peer2peerTestNUMA" time="0"><skipped>Skipped by script</skipped></testcase>' >> "$TMPXML"
skipped=$((skipped + 1))

for exe in $(find "$BUILD_DIR" -mindepth 2 -maxdepth 2 -type f -executable \
  ! -path "*/CMakeFiles/*" \
  ! -path "$BUILD_DIR/SMs/*" \
  ! -path "$BUILD_DIR/memory/peer2peerTestNUMA" | sort); do

  name="${exe#${BUILD_DIR}/}"
  runlog=$(mktemp)

  # Store the total execution time per benchmark, although it is not so precise as the
  # numbers reported from each benchmark.
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
    echo "  <testcase classname=\"cudahandbook\" name=\"$name\" time=\"$runtime\"/>" >> "$TMPXML"
  else
    echo "  <testcase classname=\"cudahandbook\" name=\"$name\" time=\"$runtime\"><failure message=\"run failed\"/></testcase>" >> "$TMPXML"
  fi

  rm -f "$runlog"
done

total=$((passed + failed + skipped))

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo "<testsuite name=\"cudahandbook\" tests=\"$total\" failures=\"$failed\" skipped=\"$skipped\">"
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
