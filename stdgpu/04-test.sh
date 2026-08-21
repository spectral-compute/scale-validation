#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd "build/bin"

while read -r F; do
    case "$F" in
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
    echo -e "Running '$F'..."
    "$F"
done < <(find . -type f -executable)
