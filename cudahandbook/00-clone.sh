#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# cudahandbook doesn't do tags, releases, or release branches, it seems.
do_clone cudahandbook https://github.com/ArchaeaSoftware/cudahandbook.git "$(get_version cudahandbook)"
