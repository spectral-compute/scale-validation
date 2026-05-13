#!/bin/bash
set -u

OUT_DIR="$(realpath .)/HeCBench"
BUILD_DIR="${OUT_DIR}/build/cuda-sm${CUDAARCHS}"
BIN_DIR="${BUILD_DIR}/bin/cuda"

LOGFILE="$BUILD_DIR/hecbench-run.log"
NUMBERSFILE="$BUILD_DIR/hecbench-numbers.txt"
XMLFILE="$BUILD_DIR/hecbench-run.xml"
TMPXML="$BUILD_DIR/.tmp_cases.xml"

# : > "$LOGFILE"
# : > "$NUMBERSFILE"
# : > "$TMPXML"

CUDA_ARCH_NUM="${CUDAARCHS#sm_}"

python3 $OUT_DIR/tools/hecbench --verbose run --model cuda --preset scale-cuda-sm$CUDA_ARCH_NUM
exit


# These tests are excluded for the following reasons:
exclude=(
  # The following hang or take too long to complete
  cm
  divergence
  mdh
  ising
  laplace
  logic-rewrite

  # Outright failures
  blas-gemmEx
  bsw
  che
  egs  
  f16sp
  geam          
  graphExecution
  hybridsort  
  jaccard                  
  lfib4                   
  norm2                   
  openmp                  
  opticalFlow             
  p2p                     
  quantAQLM               
  rainflow                
  rayleighBenardConvection
  sddmm-batch             
  simplemoc               
  slit                    
  spaxpby                 
  spd2s                   
  spgemm                  
  spmm                    
  spmv                    
  spnnz                   
  sps2d                   
  spsm                    
  spsort                  

  # Flaky failures
  axhelm   
  bicgstab 
  blas-dot 
  blas-gemm
  blas-gemmEx2
  clenergy   
  contract   
  determinant
  dwconv     
  gamma-correction
  inversek2j
  kmc     
  ludb    
  minibude
  mrg32k3a
  pcc
)
# TODO: Fix these
# TODO: Also fix benchmark compilation failures and verify they run


passed=0
failed=0
skipped="${#exclude[@]}"

for name in "${exclude[@]}"; do
  echo "  <testcase classname=\"hecbench\" name=\"src/$name-cuda\" time=\"0\"><skipped>Skipped by script</skipped></testcase>" >> "$TMPXML"
done


find_args=()

for name in "${exclude[@]}"; do
  find_args+=( ! -name "$name" )
done

for exe in $(
  find "$BIN_DIR" \
  -mindepth 1 -maxdepth 1 \
  -type f -executable \
  "${find_args[@]}" \
  | sort
); do
  name="${exe#${OUT_DIR}/}"
  runlog=$(mktemp)

  echo "Executing $name" | tee -a "$LOGFILE"

  pushd $(dirname $exe)
  echo "ANDY: In directory -> $(pwd)"

  start=$(date +%s)

  if make ARCH=sm_$CUDA_ARCH_NUM run > "$runlog" 2>&1; then
    passed=$((passed + 1))
    status="passed"
  else
    failed=$((failed + 1))
    status="failed"
  fi

  end=$(date +%s)
  runtime=$((end - start))

  popd

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
