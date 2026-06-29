#!/bin/bash
set -ETeuo pipefail

cd ExtendedOpenDwarfs

export LC_ALL=C
export LANG=C

export APP="${EOD_APP:-${TEST_APP:-fft}}"
export BACKEND="${EOD_BACKEND:-${TEST_BACKEND:-cuda}}"
export COMPILER="${EOD_COMPILER:-${TEST_COMPILER:-scale-amd}}"
export SIZE="${EOD_SIZE:-${TEST_SIZE:-tiny}}"
export ITERS="${EOD_ITERS:-${TEST_ITERS:-1}}"

if [[ "$COMPILER" == scale-* ]]; then
	export ODW_USE_SCALE=1
fi


# Derive SCALE_ROOT from PATH left behind by scale-validation's scaleenv.
if [[ -z "${SCALE_ROOT:-}" ]]; then
	SCALE_LLVM_BIN="$(printf '%s\n' "${PATH//:/$'\n'}" | grep -m1 '/scale-[^/]*/bin/../llvm/bin$' || true)"
	if [[ -n "$SCALE_LLVM_BIN" ]]; then
		SCALE_ROOT="$(cd "${SCALE_LLVM_BIN}/../.." && pwd)"
		export SCALE_ROOT
	fi
fi

# scale-validation may not export SCALE_ROOT directly. Derive it when possible.
if [[ -z "${SCALE_ROOT:-}" ]]; then
	if [[ -n "${CUDA_PATH:-}" && "${CUDA_PATH}" == */targets/* ]]; then
		SCALE_ROOT="$(cd "${CUDA_PATH}/../.." && pwd)"
	elif [[ -x "${PWD}/../scale-1.7.1-Linux/bin/scaleenv" ]]; then
		SCALE_ROOT="$(cd "${PWD}/../scale-1.7.1-Linux" && pwd)"
	fi
	export SCALE_ROOT
fi



unset CFLAGS
unset CXXFLAGS
unset NVCC_PREPEND_FLAGS
unset NVCC_APPEND_FLAGS
unset CMAKE_COLOR_DIAGNOSTICS


make run \
	APP="$APP" \
	BACKEND="$BACKEND" \
	COMPILER="$COMPILER" \
	SIZE="$SIZE" \
	ITERS="$ITERS" \
	DO_PLOTS=0
