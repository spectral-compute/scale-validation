#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/xgboost"
cd "${OUT_DIR}/xgboost"

do_clone xgboost https://github.com/dmlc/xgboost.git "$(get_version xgboost)"
do_clone_hash House-Prices-Advanced-Regression https://github.com/ankita1112/House-Prices-Advanced-Regression.git "$(get_version House-Prices-Advanced-Regression)"
do_clone_hash datasets https://github.com/martandsingh/datasets.git "$(get_version datasets)"
