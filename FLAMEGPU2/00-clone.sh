#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone FLAMEGPU2 https://github.com/FLAMEGPU/FLAMEGPU2.git "$(get_version FLAMEGPU2)"
