#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash sage https://github.com/spcl/sage.git cdb3b06
