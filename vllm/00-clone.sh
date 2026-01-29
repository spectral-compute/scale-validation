#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone vllm https://github.com/vllm-project/vllm.git "$(get_version vllm)"
