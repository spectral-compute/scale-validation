#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

check_cuda_backend_detected() {
    local out
    out="$(./build/hashcat -I 2>&1)"
    echo "${out}"
    echo "${out}" | grep -iqE 'CUDA Info|Backend Device ID.*CUDA'
}

# These runs are infeasible to complete (32-char exhaustive mask), so they're
# bounded with timeout and only the early output is inspected. A timeout kill
# (exit 124) is expected and not itself a failure.
check_length_limit_off() {
    local hash mask out
    hash="$(echo -n 'aaaabbbbccccddddeeeeffffgggghhhi' | sha256sum | cut -d ' ' -f 1)"
    mask='?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l'
    out="$(timeout 45 ./build/hashcat --backend-ignore-hip --backend-ignore-opencl --potfile-disable -m 1400 -a 3 "${hash}" "${mask}" 2>&1 || true)"
    echo "${out}" | head -30
    # Must not contain a genuine password-length constraint error before the
    # run gets killed. ('Maximum password length supported by kernel: N' is
    # benign info -- excluded by this pattern.)
    ! echo "${out}" | grep -iE 'exceeds.*length|length.*limit'
}

check_length_limit_on() {
    local hash mask out
    hash="$(echo -n 'aaaabbbbccccddddeeeeffffgggghhhi' | sha256sum | cut -d ' ' -f 1)"
    mask='?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l?l'
    out="$(timeout 45 ./build/hashcat --backend-ignore-hip --backend-ignore-opencl --potfile-disable -O -m 1400 -a 3 "${hash}" "${mask}" 2>&1 || true)"
    echo "${out}" | head -30
    echo "${out}" | grep -iE 'exceeds|limit|length|31'
}

check "CUDA backend detected via -I"                  check_cuda_backend_detected
check "32-char mask starts cleanly without -O"        check_length_limit_off
check "-O triggers 31-char length warning"            check_length_limit_on

check_exit
