#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone cusz https://github.com/szcompressor/cuSZ.git "$(get_version cusz)"
