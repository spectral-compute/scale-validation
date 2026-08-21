#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone caffe https://github.com/BVLC/caffe.git "$(get_version caffe)"
