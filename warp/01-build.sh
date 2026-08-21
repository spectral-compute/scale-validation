#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd warp
python3 build_lib.py --use-dynamic-cuda
