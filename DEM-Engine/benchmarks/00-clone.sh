#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# DEME 3 (main) dropped the native HIP backend, so benchmarks use v2.4.2 for every toolchain.
do_clone DEM-Engine https://github.com/projectchrono/DEM-Engine.git "$(get_version DEM-Engine-v2)"

# Upstream's demos simulate tens of seconds and write output every frame: build a fixed-length,
# output-free variant of two of them alongside.
cp "$(dirname "$0")"/DEMBench.cpp DEM-Engine/src/demo/
sed -i 's/^SET(DEMOS$/&\n\t\tDEMBench/' DEM-Engine/src/demo/CMakeLists.txt
grep -q DEMBench DEM-Engine/src/demo/CMakeLists.txt
