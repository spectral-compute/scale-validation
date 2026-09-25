#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone xgboost https://github.com/dmlc/xgboost.git "$(get_version xgboost)"
do_clone House-Prices-Advanced-Regression https://github.com/ankita1112/House-Prices-Advanced-Regression.git "$(get_version House-Prices-Advanced-Regression)"
do_clone datasets https://github.com/martandsingh/datasets.git "$(get_version datasets)"
