#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash caffe https://github.com/BVLC/caffe.git "$(get_version caffe)"
