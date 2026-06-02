#!/bin/bash
set -ETeuo pipefail
shopt -s nullglob

cd pytorch
source $(dirname $0)/common.sh

cd build/pytorch
python setup.py build
python setup.py install --root=$PWD/../../install --skip-build
