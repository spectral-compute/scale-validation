#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone cudf https://github.com/rapidsai/cudf "$(get_version cudf)"
