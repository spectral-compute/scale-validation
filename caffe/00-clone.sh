#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone caffe https://github.com/BVLC/caffe.git "$(get_version caffe)"
