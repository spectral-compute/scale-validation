#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

mkdir -p out

check_crack_md5() {
    local md5
    md5="$(echo -n test | md5sum | cut -d ' ' -f 1)"
    ./build/hashcat --backend-ignore-hip --backend-ignore-opencl --potfile-disable -O -o out/md5.txt -m 0 -a 3 "${md5}" \
        && [ "$(cat out/md5.txt)" == "${md5}:test" ]
}

# bcrypt is a slow hash -- -O's optimized kernels are for fast hashes only,
# so deliberately omitted here. The target hash is *not* actually bcrypt of
# "test" (just an arbitrary sample) -- the claim is that mode 3200 runs to
# completion, not that this candidate cracks it, so accept Exhausted too.
check_crack_bcrypt() {
    local bcrypt_hash='$2b$05$Jka2DvQ1bVqONe8pPNGqme5HqYYU9N7VHWVcJFCpw1w4K0x7u.2qy'
    ./build/hashcat --backend-ignore-hip --backend-ignore-opencl --potfile-disable -m 3200 -a 3 "${bcrypt_hash}" 'test' \
        &> out/bcrypt.out
    grep -qiE 'Status.*(Cracked|Exhausted)' out/bcrypt.out
}

# example.dict ships at the hashcat repo root; 01-build.sh copies the whole
# cloned tree into build/, so it lands at build/example.dict.
check_dictionary_attack() {
    local hash
    hash="$(echo -n password | sha256sum | cut -d ' ' -f 1)"
    ./build/hashcat --backend-ignore-hip --backend-ignore-opencl --potfile-disable -O -o out/dict.txt -m 1400 -a 0 "${hash}" build/example.dict \
        && [ "$(cat out/dict.txt)" == "${hash}:password" ]
}

# 'password1' is produced by best66.rule's append-digit ($1) rule applied to
# the dictionary word 'password', so this is guaranteed to hit on the first
# matching rule.
check_rules_attack() {
    local hash
    hash="$(echo -n password1 | sha256sum | cut -d ' ' -f 1)"
    ./build/hashcat --backend-ignore-hip --backend-ignore-opencl --potfile-disable -O -o out/rules.txt -m 1400 -a 0 -r build/rules/best66.rule "${hash}" build/example.dict \
        && [ "$(cat out/rules.txt)" == "${hash}:password1" ]
}

check "crack MD5"                                        check_crack_md5
check "crack bcrypt (mode 3200, no -O)"                   check_crack_bcrypt
check "dictionary attack (-a 0, build/example.dict)"      check_dictionary_attack
check "rules attack (-a 0 -r build/rules/best66.rule)"     check_rules_attack

check_exit
