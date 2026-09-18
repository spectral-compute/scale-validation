#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

OUT_DIR="$(realpath .)"
SRC_DIR="${OUT_DIR}/HeCBench"

build_status=0

case "${TEST_MODE}" in
    scale-amd|scale-nvidia)
		# Expect CUDAARCHS like 80, 86, 90 — not sm_80
		CUDA_ARCH_NUM="${CUDAARCHS#sm_}"

		export CUDAFLAGS="-Wno-cuda-implicit-real-arch -Wno-unused-command-line-argument -Wno-write-strings"

		python3 "$SRC_DIR/tools/hecbench" --verbose build --preset "scale-cuda-sm${CUDA_ARCH_NUM}"
		build_status=$?
		;;

	hip-amd)
		python3 "$SRC_DIR/tools/hecbench" --verbose build --preset "hip-${TEST_GPU_ARCH}"
		build_status=$?
		;;

	nvcc-nvidia)
		# Expect CUDAARCHS like 80, 86, 90 — not sm_80
		CUDA_ARCH_NUM="${CUDAARCHS#sm_}"

		export CUDAFLAGS="-Wno-cuda-implicit-real-arch -Wno-unused-command-line-argument -Wno-write-strings"

		python3 "$SRC_DIR/tools/hecbench" --verbose build --preset "cuda-sm${CUDA_ARCH_NUM}"
		build_status=$?
		;;

	*)
		echo "Unrecognised test mode: $TEST_MODE"
		exit 1
		;;
esac

if [ "$build_status" -ne 0 ]; then
    echo "hecbench build failed with exit code ${build_status}" >&2
    exit "$build_status"
fi
