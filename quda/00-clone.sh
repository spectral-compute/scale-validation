#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash quda https://github.com/lattice/quda.git "$(get_version quda)"
