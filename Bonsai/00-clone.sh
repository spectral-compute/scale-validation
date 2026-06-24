#!/bin/bash

set -euo pipefail
source "$(dirname "$0")"/../util/git.sh

do_clone_hash Bonsai https://github.com/treecode/Bonsai.git "$(get_version Bonsai)"
