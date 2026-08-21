#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

(cd cudf && ./build.sh --pydevelop libcudf libcudf_kafka cudf dask_cudf cudf_kafka custreamz)
