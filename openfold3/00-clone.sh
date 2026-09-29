#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone openfold-3 https://github.com/aqlaboratory/openfold-3.git "$(get_version openfold3)"
