#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone jitify https://github.com/NVIDIA/jitify.git "$(get_version jitify)"
