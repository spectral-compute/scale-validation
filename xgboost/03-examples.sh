#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

# TODO: Should libomp/libgomp/etc be in the target libraries? Should we ship OpenMP?
export LD_LIBRARY_PATH="${CUDA_PATH}/lib:${CUDA_PATH}/../../llvm/lib/x86_64-unknown-linux-gnu"

# Look for the Python package. These end up in different places on Arch and Ubuntu.
for D in "${OUT_DIR}/xgboost/install/lib/python${PY_VER_PATH}/site-packages" \
         "${OUT_DIR}/xgboost/install/local/lib/python${PY_VER_PATH}/dist-packages" ; do
    if [ -e "${D}" ] ; then
        export PYTHONPATH="${D}"
        break
    fi
done
if [ -z "${PYTHONPATH:-}" ] ; then
    echo "Could not find built xgboost Python package." 1>&2
    exit 1
fi

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
