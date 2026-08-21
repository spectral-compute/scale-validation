#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

mkdir -p out

HASH="$(echo -n test | sha256sum | cut -d ' ' -f 1)"
./build/hashcat --backend-ignore-hip --backend-ignore-opencl --potfile-disable -O -o out/test.txt -m 1400 -a 3 "${HASH}"

if [ "$(cat out/test.txt)" == "${HASH}:test" ]; then
    exit 0
fi

exit 1
