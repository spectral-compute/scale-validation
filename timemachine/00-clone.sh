#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash timemachine https://github.com/proteneer/timemachine.git "$(get_version timemachine)"

# Upstream bug means `CMAKE_CXX_FLAGS` fails with this project,
# so disable Werror a weirder way:
sed -Ee 's/-Werror ?(all-warnings ?)?//g' -i"" timemachine/cpp/CMakeLists.txt
