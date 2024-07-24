#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"
cd "${OUT_DIR}/hashcat"

rm -rf build install
cp -r --reflink=auto hashcat build

make -C build
