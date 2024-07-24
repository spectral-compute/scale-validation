#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/stdgpu/build/bin"

for F in $(find . -type f -executable) ; do
    case $F in
        ./benchmarkstdgpu)
            continue
        ;;
        ./teststdgpu)
            continue
        ;;
    esac
    $F
done
