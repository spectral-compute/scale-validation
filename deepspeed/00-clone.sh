#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone DeepSpeed https://github.com/deepspeedai/DeepSpeed.git "$(get_version deepspeed)"
