#!/bin/bash
#
# Clone code_saturne at the version pinned in versions.txt.

set -ETeuo pipefail

# shellcheck source=../util/git.sh
source "$(dirname "$0")/../util/git.sh"

do_clone_hash code_saturne https://github.com/code-saturne/code_saturne.git "$(get_version code_saturne)"
