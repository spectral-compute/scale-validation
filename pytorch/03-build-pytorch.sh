#!/bin/bash
set -ETeuo pipefail

cd pytorch
source $(dirname $0)/util/common.sh

cd build/pytorch
python setup.py build
python setup.py install --skip-build
