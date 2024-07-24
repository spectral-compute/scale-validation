#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/xgboost"
cd "${OUT_DIR}/xgboost"

do_clone xgboost https://github.com/dmlc/xgboost.git v2.1.0
do_clone House-Prices-Advanced-Regression https://github.com/ankita1112/House-Prices-Advanced-Regression.git f3a41e6
do_clone datasets https://github.com/martandsingh/datasets.git 5e987d5
