#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash cuml https://github.com/rapidsai/cuml.git "$(get_version cuml)"
