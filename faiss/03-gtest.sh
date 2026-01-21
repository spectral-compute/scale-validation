#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

ctest --test-dir build --output-on-failure --output-junit faiss.xml -E "MEM_LEAK.ivfflat"
