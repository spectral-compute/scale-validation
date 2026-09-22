#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

(cd cudf && ./build.sh --pydevelop libcudf libcudf_kafka cudf dask_cudf cudf_kafka custreamz)
