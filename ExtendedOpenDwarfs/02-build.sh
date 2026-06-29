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

# scale-validation injects compiler diagnostic flags globally.
# EOD manages its own flags; keep the harness from poisoning SCALE/AMD builds.
unset CFLAGS
unset CXXFLAGS
unset NVCC_PREPEND_FLAGS
unset NVCC_APPEND_FLAGS
unset CMAKE_COLOR_DIAGNOSTICS

case "$APP" in
	crc)
		make -C combinational-logic/crc clean
		make -C combinational-logic/crc datasets
		;;

	cfd)
		[[ -f test/unstructured-grids/cfd/128.dat ]] || \
			python3 scripts/generate_cfd_dataset.py \
				test/unstructured-grids/cfd/fvcorr.domn.193K \
				test/unstructured-grids/cfd/128.dat \
				128

		[[ -f test/unstructured-grids/cfd/1284.dat ]] || \
			python3 scripts/generate_cfd_dataset.py \
				test/unstructured-grids/cfd/fvcorr.domn.193K \
				test/unstructured-grids/cfd/1284.dat \
				1284

		[[ -f test/unstructured-grids/cfd/45056.dat ]] || \
			python3 scripts/generate_cfd_dataset.py \
				test/unstructured-grids/cfd/fvcorr.domn.193K \
				test/unstructured-grids/cfd/45056.dat \
				45056

		[[ -f test/unstructured-grids/cfd/193474.dat ]] || \
			python3 scripts/generate_cfd_dataset.py \
				test/unstructured-grids/cfd/fvcorr.domn.193K \
				test/unstructured-grids/cfd/193474.dat \
				193474
		;;
esac

make clean \
	APP="$APP" \
	BACKEND="$BACKEND" \
	COMPILER="$COMPILER" \
	SIZE="$SIZE" \
	ITERS="$ITERS"


# scale-validation injects diagnostic flags intended for compiler testing.
# They confuse nvcc/SCALE builds but are not required for EOD.

unset CFLAGS
unset CXXFLAGS
unset NVCC_PREPEND_FLAGS
unset NVCC_APPEND_FLAGS
unset CMAKE_COLOR_DIAGNOSTICS

if [[ "$COMPILER" == scale-* ]]; then
	export ODW_USE_SCALE=1
fi

make build \
	APP="$APP" \
	BACKEND="$BACKEND" \
	COMPILER="$COMPILER" \
	SIZE="$SIZE" \
	ITERS="$ITERS"
