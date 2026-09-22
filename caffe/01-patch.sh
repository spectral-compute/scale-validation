#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

patch -p0 -d "caffe" <"${SCRIPT_DIR}/protobuf.patch"
