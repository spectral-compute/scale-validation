#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash ggml https://github.com/ggml-org/ggml "$(get_version ggml)"
