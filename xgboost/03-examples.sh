#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Look for the Python package. These end up in different places on Arch and Ubuntu.

PY_VER_PATH=$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1-2) # Like "3.12"
for D in "install/lib/python${PY_VER_PATH}/site-packages" \
    "install/local/lib/python${PY_VER_PATH}/dist-packages"; do
    if [ -e "${D}" ]; then
        export PYTHONPATH="${D}"
        break
    fi
done
if [ -z "${PYTHONPATH:-}" ]; then
    echo "Could not find built xgboost Python package." 1>&2
    exit 1
fi

for booster in gbtree dart; do
    for tree_method in hist approx; do
        echo -e "House prices ${booster} ${tree_method} example"
        cd "House-Prices-Advanced-Regression"
        python3 "${SCRIPT_DIR}/example-house-prices.py" ${booster} ${tree_method}

        echo -e "Weather ${booster} ${tree_method} example"
        cd "datasets"
        python3 "${SCRIPT_DIR}/example-weather.py" ${booster} ${tree_method}
    done
done
