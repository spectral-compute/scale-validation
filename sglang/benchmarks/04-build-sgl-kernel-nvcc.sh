#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# The base folder's build, without its SCALE workarounds (FA3 off).
source "${SCALE_VALIDATION}/pytorch/util/build-env.sh"
source .venv/bin/activate

export CMAKE_BUILD_PARALLEL_LEVEL="${MAX_JOBS}"

python -m pip install "scikit-build-core>=0.10" "cmake>=3.26" ninja wheel
python -m pip install --no-build-isolation --no-deps -v ./sglang/python/sglang/kernels/aot
