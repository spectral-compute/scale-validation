#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cp MAGMA/testing/run_tests.py build/testing/

(cd "build/testing/" && ./run_tests.py)
