#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

./build/mlp_learning_an_image tiny-cuda-nn/data/images/albert.jpg 10000
