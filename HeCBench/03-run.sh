#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

OUT_DIR="$(realpath .)/HeCBench"
RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"


mkdir -p "$RESULTS_DIR"
if [[ "$TEST_TOOLCHAIN" == "scale" ]]; then
	if command -v scaleinfo > /dev/null; then
		scaleinfo > "${RESULTS_DIR}/scale_info.txt"
	elif [[ -x "$TOOLKIT_DIR/bin/scaleinfo" ]]; then
		"$TOOLKIT_DIR/bin/scaleinfo" > "${RESULTS_DIR}/scale_info.txt"
	else
		echo "Error: Cannot find scaleinfo for this scale run." 1>&2
		exit 1
	fi
else
    lspci 2>/dev/null | grep -i 'vga\|display' > "${RESULTS_DIR}/pci_info.txt" || true
fi


TEST_DT=$(date '+%Y%m%d-%H%M%S')


case "${TEST_MODE}" in
    scale-amd|scale-nvidia)
		CUDA_ARCH_NUM="${CUDAARCHS#sm_}"
		DATA_FILE="hecbench.scale.$TEST_GPU_ARCH.cuda-sm$CUDA_ARCH_NUM.$TEST_DT.csv"

		python3 "$OUT_DIR/tools/hecbench" run \
			--model cuda \
			--preset "scale-cuda-sm$CUDA_ARCH_NUM" \
			--store "hecbench-results.scale.$TEST_GPU_ARCH.cuda-sm$CUDA_ARCH_NUM.db" \
			--format csv \
			--output "$RESULTS_DIR/$DATA_FILE"
		;;

	hip-amd)
		if [[ -z "$HIP_VISIBLE_DEVICES" ]]; then
			echo "HIP_VISIBLE_DEVICES required to be set" 1>&2
			exit 1
		fi
		
		DATA_FILE="hecbench.hip.$TEST_GPU_ARCH.hip-$TEST_GPU_ARCH.$TEST_DT.csv"

		python3 "$OUT_DIR/tools/hecbench" run \
			--model hip \
			--preset "hip-$TEST_GPU_ARCH" \
			--store "hecbench-results.hip.$TEST_GPU_ARCH.hip-$TEST_GPU_ARCH.db" \
			--format csv \
			--output "$RESULTS_DIR/$DATA_FILE"
		;;

	nvcc-nvidia)
		CUDA_ARCH_NUM="${CUDAARCHS#sm_}"
		DATA_FILE="hecbench.nvcc.$TEST_GPU_ARCH.cuda-sm$CUDA_ARCH_NUM.$TEST_DT.csv"

		python3 "$OUT_DIR/tools/hecbench" run \
			--model cuda \
			--preset "cuda-sm$CUDA_ARCH_NUM" \
			--store "hecbench-results.nvcc.$TEST_GPU_ARCH.cuda-sm$CUDA_ARCH_NUM.db" \
			--format csv \
			--output "$RESULTS_DIR/$DATA_FILE"
		;;

	*)
		echo "Unrecognised test mode: $TEST_MODE"
		exit 1
		;;
esac

if [ "$(wc -l < "$RESULTS_DIR/$DATA_FILE")" -le 1 ]; then
    echo "hecbench produced no results (every benchmark skipped)" >&2
    exit 1
fi
