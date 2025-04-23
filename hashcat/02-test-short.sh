#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"
cd "${OUT_DIR}/hashcat"

mkdir -p out
rm -f out/test.txt

HASH="$(echo -n test | sha256sum | cut -d ' ' -f 1)"
build/hashcat --backend-ignore-hip --backend-ignore-opencl --potfile-disable -O -o out/test.txt -m 1400 -a 3 "${HASH}"

if [ "$(cat out/test.txt)" == "${HASH}:test" ] ; then
    exit 0
fi

exit 1
