#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

./build/mlp_learning_an_image tiny-cuda-nn/data/images/albert.jpg 10000
