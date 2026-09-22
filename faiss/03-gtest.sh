#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

ctest --test-dir build --verbose --output-junit faiss.xml -E "MEM_LEAK.ivfflat"
