#!/bin/bash

set -ETeuo pipefail

# Look for the Python package. These end up in different places on Arch and Ubuntu.

PY_VER_PATH=$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1-2) # Like "3.12"
for D in "install/lib/python${PY_VER_PATH}/site-packages" \
         "install/local/lib/python${PY_VER_PATH}/dist-packages" ; do
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
        cd "House-Prices-Advanced-Regression"
        python3 "${THIS_PATH}/example-house-prices.py" ${booster} ${tree_method}

        echo -e "\x1b[32;1mWeather ${booster} ${tree_method} example\x1b[m"
        cd "datasets"
        python3 "${THIS_PATH}/example-weather.py" ${booster} ${tree_method}
    done
done
