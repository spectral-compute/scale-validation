#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# SCALE has no CUPTI. cuPHY uses it only in a tracing helper that nothing in cuPHY itself calls,
# and in the example that demonstrates that helper.
if [[ -n "${SCALE_ENV:-}" ]]; then
    sed -i -e '/^\s*cupti_helper\.cpp$/d' -e '/CUDA::cupti/d' aerial/cuPHY/src/cuphy/CMakeLists.txt
    sed -i -e '/add_subdirectory(cupti_example)/d' aerial/cuPHY/examples/CMakeLists.txt
fi
