#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

cp MAGMA/testing/run_tests.py build/testing/

(cd "build/testing/" && ./run_tests.py)
