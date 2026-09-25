#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

patch -p0 -d "caffe" <"${SCRIPT_DIR}/protobuf.patch"
