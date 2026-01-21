#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash alien https://github.com/chrxh/alien.git "$(get_version alien)"
