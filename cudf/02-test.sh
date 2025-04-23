#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd cudf/cudf
ctest --test-dir ${CUDF_HOME}/cpp/build  # libcudf
ctest --test-dir ${CUDF_HOME}/cpp/libcudf_kafka/build  # libcudf_kafka
pytest -v python/cudf/cudf/tests
pytest -v python/dask_cudf/dask_cudf/ # There are tests in both tests/ and io/tests/
pytest -v python/custreamz/custreamz/tests