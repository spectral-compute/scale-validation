#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone cuSZ https://github.com/szcompressor/cuSZ.git "$(get_version cuSZ)"
