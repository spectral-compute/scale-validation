#!/bin/bash
# =============================================================================
# Cutlass Profiler – mini guide
# -----------------------------------------------------------------------------
# Does:
#   • Builds cutlass_profiler
#   • Auto-discovers targets → (operation, --kernels=pattern) pairs (deduped)
#   • Runs profiler (capped) → writes profiler.log + JUnit + CSV metrics
# =============================================================================

set -ETeuo pipefail

# Optional skipping (colon-separated globs matched against full target)
# e.g., SKIP_PATTERNS='*planar_complex*:*cf32*'
#SKIP_PATTERNS="${SKIP_PATTERNS:-}"
SKIP_PATTERNS='*static*'

# Limit number of (operation,kernel-pattern) runs (default: 2 for quick smoke test)
#MAX_PAIRS="${MAX_PAIRS:-2}"
MAX_PAIRS="${MAX_PAIRS:-120}" # Decrease tests from 235 to 120 

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/cutlass/build" || {
  echo "Build dir not found: ${OUT_DIR}/cutlass/build" >&2
  exit 1
}

# ---------- Build cutlass_profiler (log to file) ----------
BUILD_LOG="${OUT_DIR}/cutlass/build/cutlass_profiler.build.log"
mkdir -p "$(dirname "$BUILD_LOG")"
: > "$BUILD_LOG"
echo "Building cutlass_profiler (logging to $BUILD_LOG)..."
set +e
make -j cutlass_profiler >"$BUILD_LOG" 2>&1
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo "cutlass_profiler build failed. Last 200 lines from $BUILD_LOG:"
  tail -n 200 "$BUILD_LOG"
  exit $rc
fi

# ---------- Auto-generate targets log ----------
TARGETS_LOG="${OUT_DIR}/cutlass/build/targets.log"

gen_targets_log() {
  local out="$1"
  : > "$out"

  local gen
  gen=$(grep -E '^(CMAKE_GENERATOR(:INTERNAL)?=)' CMakeCache.txt 2>/dev/null | tail -n1 | cut -d= -f2 || true)

  # 1) Use generator-native listing
  if [[ "$gen" == "Ninja" || -f build.ninja ]]; then
    ( ninja -t targets all 2>/dev/null || ninja -t targets 2>/dev/null ) \
      | awk -F: '{print $1}' | grep -E '^cutlass_library_' | sort -u >> "$out" || true
  elif [[ "$gen" == "Unix Makefiles" || -f Makefile ]]; then
    make help | grep -oE 'cutlass_library_[A-Za-z0-9_]+' | sort -u >> "$out" || true
  fi

  # 2) Fallbacks: search build metadata or build log
  if [[ ! -s "$out" ]]; then
    grep -RhoE 'cutlass_library_[A-Za-z0-9_]+' CMakeFiles 2>/dev/null | sort -u >> "$out" || true
  fi
  if [[ ! -s "$out" && -f "$BUILD_LOG" ]]; then
    grep -oE 'cutlass_library_[A-Za-z0-9_]+' "$BUILD_LOG" | sort -u >> "$out" || true
  fi

  if [[ ! -s "$out" ]]; then
    echo "Could not generate targets log automatically (empty list)." >&2
    return 1
  fi
  echo "Generated targets log (${gen:-unknown}): $out"
}

gen_targets_log "$TARGETS_LOG" || exit 3

# ---------- Paths & logs ----------
LOGFILE="${OUT_DIR}/cutlass/build/profiler.log"
REPORT_JUNIT="${OUT_DIR}/cutlass/build/profiler-report.xml"
mkdir -p "$(dirname "$LOGFILE")"
: > "$LOGFILE"
echo "Writing to $LOGFILE"
echo "Using targets log: $TARGETS_LOG"

# ---------- Profiler knobs (env-tunable) ----------
PROFILER="${PROFILER:-./tools/profiler/cutlass_profiler}"
WARMUP="${WARMUP:-5}"
ITERS="${ITERS:-30}"
VERIFY="${VERIFY:-false}"
read -r -a PROFILER_EXTRA_ARR <<< "${PROFILER_EXTRA:-}"

# Problem sizes (override via env if needed)
GEMM_M="${GEMM_M:-4096}"; GEMM_N="${GEMM_N:-4096}"; GEMM_K="${GEMM_K:-4096}"
C2D_N="${C2D_N:-8}"; C2D_H="${C2D_H:-224}"; C2D_W="${C2D_W:-224}"; C2D_C="${C2D_C:-128}"
C2D_K="${C2D_K:-128}"; C2D_R="${C2D_R:-3}"; C2D_S="${C2D_S:-3}"; C2D_PAD="${C2D_PAD:-1}"
C3D_N="${C3D_N:-4}"; C3D_D="${C3D_D:-32}"; C3D_H="${C3D_H:-32}"; C3D_W="${C3D_W:-32}"
C3D_C="${C3D_C:-64}"; C3D_K="${C3D_K:-64}"; C3D_T="${C3D_T:-3}"; C3D_R="${C3D_R:-3}"; C3D_S="${C3D_S:-3}"; C3D_PAD="${C3D_PAD:-1}"
RANKK_N="${RANKK_N:-4096}"; RANKK_K="${RANKK_K:-4096}"
RANK2K_N="${RANK2K_N:-4096}"; RANK2K_K="${RANK2K_K:-4096}"
SYMM_M="${SYMM_M:-4096}"; SYMM_N="${SYMM_N:-4096}"; SYMM_SIDE="${SYMM_SIDE:-left}"; SYMM_UPLO="${SYMM_UPLO:-lower}"
TRMM_M="${TRMM_M:-4096}"; TRMM_N="${TRMM_N:-4096}"; TRMM_SIDE="${TRMM_SIDE:-left}"; TRMM_UPLO="${TRMM_UPLO:-lower}"

# ---------- helpers ----------
op_from_target() {
  case "$1" in
    cutlass_library_gemm_*)    echo "Gemm" ;;
    cutlass_library_conv2d_*)  echo "Conv2d" ;;
    cutlass_library_conv3d_*)  echo "Conv3d" ;;
    cutlass_library_rank_k_*)  echo "RankK" ;;
    cutlass_library_rank_2k_*) echo "Rank2K" ;;
    cutlass_library_symm_*)    echo "Symm" ;;
    cutlass_library_trmm_*)    echo "Trmm" ;;
    *)                         echo "" ;;
  esac
}

# NEW: extract arch token (smXX, sm90a, gfx1100, etc.)
arch_from_target() {
  local t="$1" core="${t#cutlass_library_}"
  core="${core#gemm_}"; core="${core#conv2d_}"; core="${core#conv3d_}"
  core="${core#rank_k_}"; core="${core#rank_2k_}"; core="${core#symm_}"; core="${core#trmm_}"
  core="${core%_objs}"
  case "$core" in
    sm*_* )  echo "${core%%_*}"; return ;;
    gfx*_* ) echo "${core%%_*}"; return ;;
    * )      echo ""; return ;;
  esac
}

# Modified: strip any leading arch (sm*/gfx*) so patterns match profiler names
kernel_pat_from_target() {
  local t="$1" core="${t#cutlass_library_}"
  core="${core#gemm_}"; core="${core#conv2d_}"; core="${core#conv3d_}"
  core="${core#rank_k_}"; core="${core#rank_2k_}"; core="${core#symm_}"; core="${core#trmm_}"
  core="${core%_objs}"
  case "$core" in
    sm*_*  ) core="${core#*_}" ;;   # drop 'smXX_' or 'sm90a_' prefix
    gfx*_* ) core="${core#*_}" ;;   # drop 'gfx1100_' prefix (SCALE)
  esac
  echo "*${core}*"
}

xml_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/\"/\&quot;/g" -e "s/'/\&apos;/g"
}

run_pair() {
  local op="$1" kpat="$2"
  local base=( --providers=cutlass
               --verification-enabled="$VERIFY"
               --warmup-iterations="$WARMUP"
               --profiling-iterations="$ITERS"
               --sort-results-flops-per-sec
               --kernels="$kpat"
               --operation="$op"
               "${PROFILER_EXTRA_ARR[@]}" )
  case "$op" in
    Gemm)   "$PROFILER" "${base[@]}" --m="$GEMM_M" --n="$GEMM_N" --k="$GEMM_K" ;;
    Conv2d) "$PROFILER" "${base[@]}" --n="$C2D_N" --h="$C2D_H" --w="$C2D_W" --c="$C2D_C" \
             --k="$C2D_K" --r="$C2D_R" --s="$C2D_S" --pad_h="$C2D_PAD" --pad_w="$C2D_PAD" ;;
    Conv3d) "$PROFILER" "${base[@]}" --n="$C3D_N" --d="$C3D_D" --h="$C3D_H" --w="$C3D_W" --c="$C3D_C" \
             --k="$C3D_K" --t="$C3D_T" --r="$C3D_R" --s="$C3D_S" \
             --pad_d="$C3D_PAD" --pad_h="$C3D_PAD" --pad_w="$C3D_PAD" ;;
    RankK)  "$PROFILER" "${base[@]}" --n="$RANKK_N"  --k="$RANKK_K" ;;
    Rank2K) "$PROFILER" "${base[@]}" --n="$RANK2K_N" --k="$RANK2K_K" ;;
    Symm)   "$PROFILER" "${base[@]}" --m="$SYMM_M" --n="$SYMM_N" --side="$SYMM_SIDE" --uplo="$SYMM_UPLO" ;;
    Trmm)   "$PROFILER" "${base[@]}" --m="$TRMM_M" --n="$TRMM_N" --side="$TRMM_SIDE" --uplo="$TRMM_UPLO" ;;
    *)      echo "Skipping unknown operation: $op" >&2; return 0 ;;
  esac
}

# ---------- collect targets ----------
mapfile -t RAW_TARGETS < <(grep -oE 'cutlass_library_[A-Za-z0-9_]+' "$TARGETS_LOG" | sort -u)

TARGETS=()
IFS=':' read -r -a _pats <<< "$SKIP_PATTERNS"
for t in "${RAW_TARGETS[@]}"; do
  skip=0
  for p in "${_pats[@]}"; do
    [[ -n "${p:-}" && "$t" == $p ]] && { skip=1; break; }
  done
  [[ $skip -eq 0 ]] && TARGETS+=("$t")
done

declare -A SEEN
PAIRS=()
for t in "${TARGETS[@]}"; do
  op="$(op_from_target "$t")"; [[ -z "$op" ]] && continue
  kpat="$(kernel_pat_from_target "$t")"
  arch="$(arch_from_target "$t")"
  key="${op}|${kpat}"
  [[ -z "${SEEN[$key]:-}" ]] && { SEEN[$key]=1; PAIRS+=("${op}|${kpat}|${arch}"); }
done

# Limit to MAX_PAIRS (default 2)
if (( ${#PAIRS[@]} > MAX_PAIRS )); then
  PAIRS=( "${PAIRS[@]:0:$MAX_PAIRS}" )
fi
echo "Executing ${#PAIRS[@]} (operation,kernel-pattern) runs (MAX_PAIRS=$MAX_PAIRS)."

# ---------- run profiler & produce JUnit ----------
FAILURES=()
TESTCASES_XML=""
TOTAL_TIME=0

for pair in "${PAIRS[@]}"; do
  op="${pair%%|*}"
  rest="${pair#*|}"
  kpat="${rest%%|*}"
  arch="${rest#*|}"
  echo "======== ${op} --kernels=${kpat} ========" | tee -a "$LOGFILE"

  run_start=$(date +%s.%N)
  RUNLOG="$(mktemp)"

  # Write a META line carrying arch/op into both logs so the parser can attach it
  echo "__META__ ARCH=${arch:-NA} OP=${op} KPAT=${kpat}" | tee -a "$LOGFILE" >>"$RUNLOG"

  set +e
  run_pair "$op" "$kpat" |& tee -a "$LOGFILE" | tee -a "$RUNLOG" >/dev/null
  rc=${PIPESTATUS[0]}
  set -e
  run_end=$(date +%s.%N)

  dur=$(python3 - <<PY
from decimal import Decimal, ROUND_HALF_UP
start=Decimal("$run_start"); end=Decimal("$run_end"); d=end-start
print(d.quantize(Decimal("0.001"), rounding=ROUND_HALF_UP))
PY
)
  TOTAL_TIME=$(python3 - <<PY
from decimal import Decimal
print(Decimal("$TOTAL_TIME")+Decimal("$dur"))
PY
)

  case_name="$(printf '%s --kernels=%s' "$op" "$kpat" | xml_escape)"
  if [[ $rc -ne 0 ]]; then
    FAILURES+=("${op}|${kpat}")
    TESTCASES_XML+=$'\n'"  <testcase name=\"$case_name\" time=\"$dur\"><failure message=\"exit code $rc\"><![CDATA[$(tail -n 50 "$RUNLOG")]]></failure></testcase>"
  else
    TESTCASES_XML+=$'\n'"  <testcase name=\"$case_name\" time=\"$dur\"/>"
  fi
  rm -f "$RUNLOG"
done

for f in "${FAILURES[@]}"; do
  echo "Failed: ${f}"
done

echo "Summary"
echo "Runs: ${#PAIRS[@]}"
echo "Failures: ${#FAILURES[@]}"

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo "<testsuite name=\"cutlass_profiler\" tests=\"${#PAIRS[@]}\" failures=\"${#FAILURES[@]}\" time=\"$TOTAL_TIME\" timestamp=\"$(date -Iseconds)\">"
  echo "$TESTCASES_XML"
  echo "</testsuite>"
} > "$REPORT_JUNIT"

echo "JUnit report: $REPORT_JUNIT"
echo "Cutlass profiler sweep finished"

# ---------- Parse profiler.log -> CSV (inline merge of parse_results_helper.sh) ----------
OUTCSV="${OUT_DIR}/cutlass/build/cutlass-profiler-kernels.csv"
echo "Parsing ${LOGFILE} -> ${OUTCSV}"

python3 - "$LOGFILE" "$OUTCSV" << 'PY'
import csv, os, re, sys

log_path, out_csv = sys.argv[1], sys.argv[2]

ansi = re.compile(r'\x1B\[[0-9;]*[A-Za-z]')
def clean(s: str) -> str:
    return ansi.sub('', s).strip()

re_meta   = re.compile(r'^__META__\s+ARCH=([^\s]+)\s+OP=([^\s]+)\s+KPAT=(.+)$')
re_op     = re.compile(r'^\s*Operation:\s*(.+)\s*$')
re_bytes  = re.compile(r'^\s*Bytes:\s*([0-9]+)\s+bytes\b')
re_flops  = re.compile(r'^\s*FLOPs:\s*([0-9]+)\s+flops\b')
re_fpb    = re.compile(r'^\s*FLOPs/Byte:\s*([0-9.]+)\b')
re_runtime= re.compile(r'^\s*Runtime:\s*([0-9.]+)\s*ms\b')
re_mem    = re.compile(r'^\s*Memory:\s*([0-9.]+)\s*GiB/s\b')
re_math   = re.compile(r'^\s*Math:\s*([0-9.]+)\s*GFLOP/s\b')

rows = []
current = None
current_arch = "NA"   # updated by __META__ lines
current_op   = ""     # not required, but kept for clarity

def flush():
    if not current:
        return
    required = ['Kernel','Bytes','FLOPs','FLOPS/Byte','Runtime_ms','Memory_GiB_s','Math_GFLOP_s']
    if all(k in current and current[k] is not None for k in required):
        rows.append(current.copy())

with open(log_path, 'r', errors='ignore') as f:
    for raw in f:
        line = clean(raw)

        m = re_meta.match(line)
        if m:
            current_arch = m.group(1) or "NA"
            current_op = m.group(2)
            continue

        m = re_op.match(line)
        if m:
            flush()
            current = {
                'Kernel': m.group(1).strip(),
                'TargetArch': current_arch,
                'Bytes': None,
                'FLOPs': None,
                'FLOPS/Byte': None,
                'Runtime_ms': None,
                'Memory_GiB_s': None,
                'Math_GFLOP_s': None,
            }
            continue

        if not current:
            continue

        m = re_bytes.match(line)
        if m:
            current['Bytes'] = int(m.group(1)); continue
        m = re_flops.match(line)
        if m:
            current['FLOPs'] = int(m.group(1)); continue
        m = re_fpb.match(line)
        if m:
            current['FLOPS/Byte'] = float(m.group(1)); continue
        m = re_runtime.match(line)
        if m:
            current['Runtime_ms'] = float(m.group(1)); continue
        m = re_mem.match(line)
        if m:
            current['Memory_GiB_s'] = float(m.group(1)); continue
        m = re_math.match(line)
        if m:
            current['Math_GFLOP_s'] = float(m.group(1)); continue

flush()

os.makedirs(os.path.dirname(out_csv), exist_ok=True)
with open(out_csv, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['Kernel','TargetArch','Bytes','FLOPs','FLOPS/Byte','Runtime_ms','Memory_GiB_s','Math_GFLOP_s'])
    for r in rows:
        w.writerow([
            r['Kernel'],
            r.get('TargetArch', 'NA'),
            r['Bytes'],
            r['FLOPs'],
            r['FLOPS/Byte'],
            r['Runtime_ms'],
            r['Memory_GiB_s'],
            r['Math_GFLOP_s'],
        ])

print(f"Wrote {len(rows)} rows to {out_csv}")
PY

echo "CSV written to: ${OUTCSV}"

# ---------- Exit code mirrors failures like tests ----------
[[ ${#FAILURES[@]} -ne 0 ]] && exit 1 || exit 0
