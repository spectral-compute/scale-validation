#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# span-lite is fetched into the build directory, so add_subdirectory needs a binary directory.
# Fixed upstream after 3.9.0.
sed -E 's|add_subdirectory\(\$\{span-lite_SOURCE_DIR\} EXCLUDE_FROM_ALL\)|add_subdirectory(${span-lite_SOURCE_DIR} ${span-lite_BINARY_DIR} EXCLUDE_FROM_ALL)|' \
    -i arrayfire/CMakeLists.txt
grep -q 'span-lite_BINARY_DIR' arrayfire/CMakeLists.txt
