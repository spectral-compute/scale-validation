#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/git.sh

do_clone lightgbm https://github.com/microsoft/LightGBM.git v4.6.0
