#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

cd "${OUT_DIR}/caffe/caffe"

set +e
"${OUT_DIR}/caffe/build/test/test.testbin"

if [ "$?" != "0" ] ; then
    exit 222
fi
