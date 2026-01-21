#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash cugraph https://github.com/rapidsai/cugraph "$(get_version cugraph)"
