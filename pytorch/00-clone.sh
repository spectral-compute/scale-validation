#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone pytorch https://github.com/pytorch/pytorch.git "$(get_version pytorch)"
