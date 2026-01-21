#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone flashinfer https://github.com/flashinfer-ai/flashinfer.git "$(get_version flashinfer)"
