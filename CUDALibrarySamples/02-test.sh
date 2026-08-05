#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# --- CONFIGURATION ---
SRC_DIR="./CUDALibrarySamples"
BIN_DIR="./install/bin"
CHECK_DIR="./expected_output"
TESTS="cuBLAS"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if command -v FileCheck &> /dev/null; then
    FC_CMD="$(command -v FileCheck)"
elif compgen -c FileCheck- &> /dev/null; then
    FC_CMD="$(command -v $(compgen -c FileCheck- | sort -V | tail -n 1))"
else
    echo -e "${RED}Error: FileCheck utility not found in PATH.${NC}"
    exit 1
fi

if [ ! -d "$BIN_DIR" ]; then
    echo -e "${RED}Error: Install directory missing. Build the samples first.${NC}"
    exit 1
fi

python3 "${SCRIPT_DIR}/generate_filecheck.py" "$SRC_DIR" "$CHECK_DIR" "$TESTS"

if [ ! -d "$CHECK_DIR" ]; then
    echo -e "${RED}Error: Failed to generate FileCheck assertions.${NC}"
    exit 1
fi

echo "======================================================="
echo "        CUDA Library Sample Output Verification"
echo "======================================================="
echo "Install directory : $(realpath "$BIN_DIR")"
echo "Expected output   : $(realpath "$CHECK_DIR")"
echo "======================================================="

PASSED=0; FAILED=0; SKIPPED=0

for test in "$CHECK_DIR"/*.txt; do
    [ -e "$test" ] || continue

    exec_name=$(basename "$test" .txt)
    bin_path="$BIN_DIR/$exec_name"

    if [ ! -x "$bin_path" ]; then
        echo -e "[${YELLOW}SKIP${NC}] Executable '$exec_name' not found."
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if fc_output=$("$bin_path" 2>&1 | "$FC_CMD" "$test" 2>&1); then
        echo -e "[${GREEN}PASS${NC}] $exec_name"
        PASSED=$((PASSED + 1))
    else
        status=$?
        echo -e "[${RED}FAIL${NC}] $exec_name (FileCheck exit status: $status)"
        echo -e "-------------------------------------------------------"
        echo "$fc_output"
        echo -e "-------------------------------------------------------"
        FAILED=$((FAILED + 1))
    fi
done

echo "======================================================="
echo "Verification Summary:"
echo -e "  ${GREEN}Passed:  $PASSED${NC}  ${RED}Failed:  $FAILED${NC}  ${YELLOW}Skipped: $SKIPPED${NC}"
echo "======================================================="

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed. Cleaning up FileCheck assertions...${NC}"
    rm -rf "$CHECK_DIR"
else
    echo -e "${YELLOW}Preserving files in '$CHECK_DIR' for debugging.${NC}"
    exit 1
fi
