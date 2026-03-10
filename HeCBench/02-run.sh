#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(pwd)/HeCBench"
OUT_DIR="$(realpath .)"

RESULTS_DIR="$OUT_DIR/HeCBench"
mkdir -p "$RESULTS_DIR"
JUNIT="$RESULTS_DIR/hecbench.xml"
CSV_OUT="$RESULTS_DIR/hecbench.csv"
SUMMARY_OUT="$RESULTS_DIR/hecbench-summary.json"

echo "Writing CSV to:   $CSV_OUT"
echo "Writing summary:  $SUMMARY_OUT"
echo "Writing JUnit to: $JUNIT"

AUTO="$REPO_ROOT/autohecbench.py"
BENCH_DATA="$REPO_ROOT/benchmarks/subset.json"
BENCH_FAILS="$REPO_ROOT/benchmarks/subset-fails.txt"

if [[ ! -f "$AUTO" ]]; then
    echo "ERROR: autohecbench.py not found at $AUTO" >&2
    exit 1
fi

if [[ ! -f "$BENCH_DATA" ]]; then
    echo "ERROR: benchmark data not found at $BENCH_DATA" >&2
    exit 1
fi

if [[ ! -f "$BENCH_FAILS" ]]; then
    echo "ERROR: benchmark fail list not found at $BENCH_FAILS" >&2
    exit 1
fi

export SCALE_EXCEPTIONS="${SCALE_EXCEPTIONS:-2}"

SM="${CUDAARCHS:?CUDAARCHS must be set by test.sh}"
REPEAT="${HECBENCH_REPEAT:-1}"

mapfile -t BENCHES < <(
python3 - "$BENCH_DATA" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for k in sorted(data.keys()):
    print(f"{k}-cuda")
PY
)

if [[ ${#BENCHES[@]} -eq 0 ]]; then
    echo "ERROR: no CUDA benchmarks found in $BENCH_DATA" >&2
    exit 1
fi

echo "[===================]"
echo "[ RUN               ] autohecbench.py for ${#BENCHES[@]} CUDA benchmarks"

set +e
python3 "$AUTO" \
    --yes-prompt \
    --output "$CSV_OUT" \
    --summary "$SUMMARY_OUT" \
    --bench-dir "$REPO_ROOT/src" \
    --bench-data "$BENCH_DATA" \
    --bench-fails "$BENCH_FAILS" \
    --nvidia-sm "$SM" \
    --repeat "$REPEAT" \
    "${BENCHES[@]}"
AUTO_RC=$?
set -e

python3 - "$CSV_OUT" "$SUMMARY_OUT" "$BENCH_FAILS" "$JUNIT" <<'PY'
import csv
import json
import os
import sys
import xml.etree.ElementTree as ET

csv_path, summary_path, fails_path, junit_path = sys.argv[1:5]

fails = set()
with open(fails_path) as f:
    for line in f:
        s = line.strip()
        if s and not s.startswith("#"):
            fails.add(s)

summary = {}
if os.path.exists(summary_path):
    with open(summary_path) as f:
        summary = json.load(f)

times = {}
if os.path.exists(csv_path):
    with open(csv_path, newline="") as f:
        for row in csv.reader(f):
            if not row:
                continue
            name = row[0].strip()
            vals = []
            for x in row[1:]:
                x = x.strip()
                if not x:
                    continue
                try:
                    vals.append(float(x))
                except ValueError:
                    pass
            if vals:
                times[name] = sum(vals) / len(vals)

for name in fails:
    summary.setdefault(name, {"compile": "skipped", "run": "skipped"})

testsuite = ET.Element("testsuite", name="hecbench")
tests = 0
failures = 0
skipped = 0

for name in sorted(summary.keys()):
    tests += 1
    t = times.get(name, 0.0)
    tc = ET.SubElement(
        testsuite,
        "testcase",
        classname="hecbench",
        name=name,
        time=f"{t:.6f}",
    )

    st = summary.get(name, {})
    comp = st.get("compile")
    run = st.get("run")

    if name in fails or comp == "skipped" or run == "skipped":
        skipped += 1
        ET.SubElement(tc, "skipped").text = "Known failure / skipped by HeCBench fail list"
    elif comp == "failed":
        failures += 1
        ET.SubElement(tc, "failure", message="Compilation failed")
    elif run == "failed":
        failures += 1
        ET.SubElement(tc, "failure", message="Execution failed")

testsuite.set("tests", str(tests))
testsuite.set("failures", str(failures))
testsuite.set("skipped", str(skipped))

ET.ElementTree(testsuite).write(junit_path, encoding="utf-8", xml_declaration=True)
PY

echo "[===================]"

if [[ ! -f "$SUMMARY_OUT" ]]; then
    echo "ERROR: autohecbench.py did not produce a summary file" >&2
    exit 1
fi

if [[ $AUTO_RC -ne 0 ]]; then
    exit "$AUTO_RC"
fi

if grep -q "<failure" "$JUNIT"; then
    exit 1
fi
