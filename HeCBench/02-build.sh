#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

OUT_DIR="$(realpath .)"
SRC_DIR="${OUT_DIR}/HeCBench"

case "${TEST_MODE}" in
    scale-amd|scale-nvidia|nvcc-nvidia)
		# Expect CUDAARCHS like 80, 86, 90 — not sm_80
		CUDA_ARCH_NUM="${CUDAARCHS#sm_}"

		export CUDAFLAGS="-Wno-cuda-implicit-real-arch -Wno-unused-command-line-argument -Wno-write-strings"

		preset_name="cuda-sm${CUDA_ARCH_NUM}"
		if [[ "${TEST_MODE}" == scale-* ]]; then
			preset_name="scale-${preset_name}"
		fi
		;;

	hip-amd)
		preset_name="hip-${TEST_GPU_ARCH}"
		;;

	*)
		echo "Unrecognised test mode: $TEST_MODE"
		exit 1
		;;
esac

build_status=0
python3 "$SRC_DIR/tools/hecbench" --verbose build --preset "${preset_name}" || build_status=$?

if [ "$build_status" -ne 0 ]; then
    echo "hecbench build failed with exit code ${build_status}" >&2
    exit "$build_status"
fi
