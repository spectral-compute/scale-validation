#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash hypre https://github.com/hypre-space/hypre.git "$(get_version hypre)"
