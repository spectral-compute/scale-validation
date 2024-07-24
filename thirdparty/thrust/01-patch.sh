#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Clang needs some help to build Thrust.
if ! ${CUDA_DIR}/bin/nvcc --version | grep clang ; then
    exit 0
fi

cd "${OUT_DIR}/thrust/thrust/dependencies/cub/cub"

# The tests compile with -Werror, but apparently NVCC's -Wall -Wextra does not warn about unused things.
sed -E '/-Werror/d' -i "${OUT_DIR}/thrust/thrust/cmake/ThrustBuildCompilerTargets.cmake"

# Disable all warnings. They're verrryy spammy, and we'll be manually debugging any failures anyway!
sed -E 's/-Wno-unused-function/-w/' -i "${OUT_DIR}/thrust/thrust/cmake/ThrustBuildCompilerTargets.cmake"

# We already have some patches for Thrust.
for PATCH in "${SCRIPT_DIR}"/../../cidm/patches/amd/cub-*.patch ; do
    echo "Applying ${PATCH}"
    patch -p2 < "${PATCH}"
done
