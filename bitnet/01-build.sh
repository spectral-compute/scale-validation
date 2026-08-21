#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

(cd "bitnet/gpu/bitnet_kernels" && bash compile.sh)
