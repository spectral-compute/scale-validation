#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# cuPHY's unit tests (gtest), which need no test vectors.
ctest --test-dir build --output-on-failure --timeout 600
