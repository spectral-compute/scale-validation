#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

# deploy.prototxt is already vendored in-tree at the pinned commit under
# caffe/models/bvlc_reference_caffenet/ -- no extra clone needed.
wget -q -O bvlc_reference_caffenet.caffemodel \
    http://dl.caffe.berkeleyvision.org/bvlc_reference_caffenet.caffemodel

check_model_zoo_forward_pass() {
    ../install/bin/caffe time \
        -model caffe/models/bvlc_reference_caffenet/deploy.prototxt \
        -weights bvlc_reference_caffenet.caffemodel \
        -gpu 0 -iterations 5
}

check "forward pass, 5 iterations, on CaffeNet weights" check_model_zoo_forward_pass

check_exit
