#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash bitnet https://github.com/microsoft/BitNet.git "$(get_version bitnet)"
