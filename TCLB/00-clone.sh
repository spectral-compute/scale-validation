#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone TCLB https://github.com/CFD-GO/TCLB.git "$(get_version TCLB)"
