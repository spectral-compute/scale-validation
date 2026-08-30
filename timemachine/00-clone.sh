#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash timemachine https://github.com/proteneer/timemachine.git "$(get_version timemachine)"

