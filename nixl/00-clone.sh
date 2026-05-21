#!/bin/bash
#
# Clone NIXL and its UCX dependency at the versions pinned in versions.txt.

set -ETeuo pipefail

# shellcheck source=../util/git.sh
source "$(dirname "$0")/../util/git.sh"

do_clone_hash nixl https://github.com/ai-dynamo/nixl.git "$(get_version nixl)"
do_clone_hash ucx https://github.com/openucx/ucx.git "$(get_version ucx)"
