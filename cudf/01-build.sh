#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/cudf/cudf"

./build.sh --pydevelop libcudf libcudf_kafka cudf dask_cudf cudf_kafka custreamz
