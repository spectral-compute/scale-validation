#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

# Upstream bug means `CMAKE_CXX_FLAGS` fails with this project,
# so disable Werror a weirder way:
sed -Ee 's/-Werror ?(all-warnings ?)?//g' -i"" timemachine/timemachine/cpp/CMakeLists.txt
