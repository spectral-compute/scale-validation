#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
export PYTHONPATH="${OUT_DIR}/xgboost/install/lib/python${PY_VER_PATH}/site-packages"

THIS_PATH="$(realpath $(dirname "$0"))"

for booster in gbtree dart ; do
    for tree_method in hist approx ; do
        echo -e "\x1b[32;1mHouse prices ${booster} ${tree_method} example\x1b[m"
        cd "${OUT_DIR}/xgboost/House-Prices-Advanced-Regression"
        python3 "${THIS_PATH}/example-house-prices.py" ${booster} ${tree_method}

        echo -e "\x1b[32;1mWeather ${booster} ${tree_method} example\x1b[m"
        cd "${OUT_DIR}/xgboost/datasets"
        python3 "${THIS_PATH}/example-weather.py" ${booster} ${tree_method}
    done
done
