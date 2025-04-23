# Check that the given cmake build directory has found a good CUDA version.

CMAKE_BUILD_DIR="$1"

# TODO: Make this check the actual directory of the found CUDA.

# Old CUDA finder.
if grep -qE "CUDA_VERSION:STRING=[0-9]+\.[0-9]+" "${CMAKE_BUILD_DIR}/CMakeCache.txt" ; then
    exit 0
fi

# New CUDA language.
if grep -qE "CMAKE_CUDA_COMPILER:(FILEPATH|STRING)=" "${CMAKE_BUILD_DIR}/CMakeCache.txt" ; then
    exit 0
fi

# Neither.
echo "CMake did not find CUDA properly" 1>&2
exit 1
