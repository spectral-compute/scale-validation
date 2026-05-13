#!/bin/bash

set -e

cd "build/bin"

for F in $(find . -type f -executable) ; do
    case $F in
        ./teststdgpu)
            # Already tested in step '02-gtest'
            continue
        ;;
        ./benchmarkstdgpu)
            # Will be run in step `04-benchmark`
            continue
        ;;
        ./unordered_set)
            # Faulty. See scale#385.
            continue
        ;;
        ./unordered_map)
            # Faulty. See scale#385.
            continue
        ;;
        ./ranges)
            # Faulty. See scale#385.
            continue
        ;;
    esac
    echo -e "Running \x1b[1m'$F'\x1b[0m..."
    $F
done
