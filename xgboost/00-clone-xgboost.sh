#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/xgboost"
cd "${OUT_DIR}/xgboost"

do_clone xgboost https://github.com/dmlc/xgboost.git "$(cat "$(dirname $0)/version.txt" | grep "xgboost" | sed "s/xgboost //g")"
do_clone_hash House-Prices-Advanced-Regression https://github.com/ankita1112/House-Prices-Advanced-Regression.git "$(cat "$(dirname $0)/version.txt" | grep "House-Prices-Advanced-Regression" | sed "s/House-Prices-Advanced-Regression //g")"
do_clone_hash datasets https://github.com/martandsingh/datasets.git "$(cat "$(dirname $0)/version.txt" | grep "datasets" | sed "s/datasets //g")"
