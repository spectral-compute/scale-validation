#!/usr/bin/env bash

set -e

if [ ! -d examples ]; then
    git clone https://github.com/pytorch/examples.git examples
else
    (cd examples && git pull)
fi

