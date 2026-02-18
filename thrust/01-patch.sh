#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
SRC_DIR="$(realpath ./thrust)"

# Clang needs some help to build Thrust.
if ! ${CUDA_PATH}/bin/nvcc --version | grep clang ; then
    exit 0
fi

cd "${SRC_DIR}/dependencies/cub/cub"

# The tests compile with -Werror, but apparently NVCC's -Wall -Wextra does not warn about unused things.
sed -E '/-Werror/d' -i "thrust/cmake/ThrustBuildCompilerTargets.cmake"

# Disable all warnings. They're verrryy spammy, and we'll be manually debugging any failures anyway!
sed -E 's/-Wno-unused-function/-w/' -i "thrust/cmake/ThrustBuildCompilerTargets.cmake"

# We already have some patches for Thrust.
for PATCH in "${SCRIPT_DIR}"/*.patch ; do
    echo "Applying ${PATCH}"
    patch -p2 < "${PATCH}"
done
