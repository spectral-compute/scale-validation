#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash hashinator https://github.com/kstppd/hashinator.git "$(get_version hashinator)"
