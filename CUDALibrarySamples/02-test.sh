#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# --- CONFIGURATION ---
SRC_DIR="./CUDALibrarySamples"
BIN_DIR="./install/bin"
CHECK_DIR="./expected_output"
TESTS="cuBLAS"

if command -v FileCheck &>/dev/null; then
    FC_CMD="$(command -v FileCheck)"
elif compgen -c FileCheck- &>/dev/null; then
    FC_CMD="$(command -v "$(compgen -c FileCheck- | sort -V | tail -n 1)")"
else
    log "Error: FileCheck utility not found in PATH."
    exit 1
fi

if [ ! -d "$BIN_DIR" ]; then
    log "Error: Install directory missing. Build the samples first."
    exit 1
fi

python3 "${SCRIPT_DIR}/generate_filecheck.py" "$SRC_DIR" "$CHECK_DIR" "$TESTS"

if [ ! -d "$CHECK_DIR" ]; then
    log "Error: Failed to generate FileCheck assertions."
fi

log "======================================================="
log "        CUDA Library Sample Output Verification"
log "======================================================="
log "Install directory : $(realpath "$BIN_DIR")"
log "Expected output   : $(realpath "$CHECK_DIR")"
log "======================================================="

PASSED=0
FAILED=0
SKIPPED=0

for test in "$CHECK_DIR"/*.txt; do
    [ -e "$test" ] || continue

    exec_name=$(basename "$test" .txt)
    bin_path="$BIN_DIR/$exec_name"

    if [ ! -x "$bin_path" ]; then
        log -e "[SKIP] Executable '$exec_name' not found."
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if fc_output=$("$bin_path" 2>&1 | "$FC_CMD" "$test" 2>&1); then
        log "[PASS] $exec_name"
        PASSED=$((PASSED + 1))
    else
        status=$?
        log "[FAIL] $exec_name (FileCheck exit status: $status)"
        log "-------------------------------------------------------"
        log "$fc_output"
        log "-------------------------------------------------------"
        FAILED=$((FAILED + 1))
    fi
done

log "======================================================="
log "Verification Summary:"
log "  Passed:  $PASSED  Failed:  $FAILED  Skipped: $SKIPPED"
log "======================================================="

if [ "$FAILED" -eq 0 ]; then
    log "All tests passed. Cleaning up FileCheck assertions..."
    rm -rf "$CHECK_DIR"
else
    log "Preserving files in '$CHECK_DIR' for debugging."
    exit 1
fi
