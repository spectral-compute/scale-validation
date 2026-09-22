#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

# Our patches don't apply to non clang-y nvcc
if ! "${CUDA_PATH}/bin/nvcc" --version | grep clang; then
    exit 0
fi

# The tests compile with -Werror, but apparently NVCC's -Wall -Wextra does not warn about unused things.
sed -E '/-Werror/d' -i "thrust/cmake/ThrustBuildCompilerTargets.cmake"

# Disable all warnings. They're verrryy spammy, and we'll be manually debugging any failures anyway!
sed -E 's/-Wno-unused-function/-w/' -i "thrust/cmake/ThrustBuildCompilerTargets.cmake"

# Make cub's debug logs a bit more compact
(cd thrust && git -C dependencies/cub apply "${SCRIPT_DIR}/cub-InlineDebug.patch")
