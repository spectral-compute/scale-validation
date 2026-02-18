#!/bin/bash

set -ETeuo pipefail

cd cudf
./build.sh --pydevelop libcudf libcudf_kafka cudf dask_cudf cudf_kafka custreamz
cd -
