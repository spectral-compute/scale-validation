#!/bin/bash
set -ETeuo pipefail

cd pytorch
source $(dirname $0)/util/common.sh

python setup.py build
python setup.py install --skip-build
