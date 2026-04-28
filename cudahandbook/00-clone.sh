#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/git.sh

# cudahandbook doesn't do tags, releases, or release branches, it seems.
do_clone_hash cudahandbook https://github.com/ArchaeaSoftware/cudahandbook.git "$(get_version cudahandbook)"
