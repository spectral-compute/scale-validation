#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/whispercpp/whispercpp"

set -o pipefail
make base.en -j10 | tee output.txt

cat output.txt | grep "And so my fellow Americans, ask not what your country can do for you, ask what you can do for your country."
