#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash gpusnek https://github.com/jndean/gpusnek.git "$(get_version gpusnek)"
