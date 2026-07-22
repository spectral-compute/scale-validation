#!/bin/bash
set -ETeuo pipefail

cd ExtendedOpenDwarfs

export LC_ALL=C
export LANG=C

export APP="${EOD_APP:-${TEST_APP:-all}}"
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

# Mirrors runner.sh's prepare_app(): several benchmarks need fixture
# datasets generated before they can run, and that step was previously
# only done by runner.sh's own sweep loop -- never by this script, which
# calls `make run` directly. Fixed here so APP=all doesn't fail on
# crc/cfd/swat/tdm due to missing generated inputs. All four checks are
# now idempotent: each skips regeneration if its expected files already
# exist.
prepare_datasets() {
	local target_app="$1"

	case "$target_app" in
	crc | all)
		if [[ -f test/combinational-logic/crc/crc_1000x2000.txt &&
			-f test/combinational-logic/crc/crc_1000x16000.txt &&
			-f test/combinational-logic/crc/crc_1000x524000.txt &&
			-f test/combinational-logic/crc/crc_1000x4194304.txt ]]; then
			echo "==> CRC datasets already present; skipping regeneration"
		else
			echo "==> Preparing CRC datasets"
			make -C combinational-logic/crc clean
			make -C combinational-logic/crc datasets
		fi
		;;
	esac

	case "$target_app" in
	cfd | all)
		echo "==> Preparing CFD datasets"
		[[ -f test/unstructured-grids/cfd/128.dat ]] ||
			python3 scripts/generate_cfd_dataset.py \
				test/unstructured-grids/cfd/fvcorr.domn.193K \
				test/unstructured-grids/cfd/128.dat \
				128
		[[ -f test/unstructured-grids/cfd/1284.dat ]] ||
			python3 scripts/generate_cfd_dataset.py \
				test/unstructured-grids/cfd/fvcorr.domn.193K \
				test/unstructured-grids/cfd/1284.dat \
				1284
		[[ -f test/unstructured-grids/cfd/45056.dat ]] ||
			python3 scripts/generate_cfd_dataset.py \
				test/unstructured-grids/cfd/fvcorr.domn.193K \
				test/unstructured-grids/cfd/45056.dat \
				45056
		[[ -f test/unstructured-grids/cfd/193474.dat ]] ||
			python3 scripts/generate_cfd_dataset.py \
				test/unstructured-grids/cfd/fvcorr.domn.193K \
				test/unstructured-grids/cfd/193474.dat \
				193474
		;;
	esac

	case "$target_app" in
	swat | all)
		echo "==> Preparing SWAT datasets"
		[[ -f test/dynamic-programming/swat/sampledb-tiny.data &&
			-f test/dynamic-programming/swat/sampledb-tiny.loc &&
			-f test/dynamic-programming/swat/sampledb-small.data &&
			-f test/dynamic-programming/swat/sampledb-small.loc &&
			-f test/dynamic-programming/swat/sampledb-medium.data &&
			-f test/dynamic-programming/swat/sampledb-medium.loc &&
			-f test/dynamic-programming/swat/sampledb-large.data &&
			-f test/dynamic-programming/swat/sampledb-large.loc ]] ||
			python3 scripts/generate_swat_dataset.py \
				test/dynamic-programming/swat/sampledb1K1 \
				test/dynamic-programming/swat
		;;
	esac

	case "$target_app" in
	tdm | all)
		echo "==> Preparing TDM datasets"
		[[ -f test/finite-state-machine/tdm/sim-64-size200-tiny.csv &&
			-f test/finite-state-machine/tdm/episodes-tiny.txt &&
			-f test/finite-state-machine/tdm/sim-64-size200-small.csv &&
			-f test/finite-state-machine/tdm/episodes-small.txt &&
			-f test/finite-state-machine/tdm/sim-64-size200-medium.csv &&
			-f test/finite-state-machine/tdm/episodes-medium.txt &&
			-f test/finite-state-machine/tdm/sim-64-size200-large.csv &&
			-f test/finite-state-machine/tdm/episodes-large.txt ]] ||
			python3 scripts/generate_tdm_dataset.py \
				test/finite-state-machine/tdm/sim-64-size200.csv \
				test/finite-state-machine/tdm/30-episodes.txt \
				--output-dir test/finite-state-machine/tdm \
				--prefix sim-64-size200 \
				--episodes-prefix episodes
		;;
	esac
}

prepare_datasets "$APP"

make run \
	APP="$APP" \
	BACKEND="$BACKEND" \
	COMPILER="$COMPILER" \
	SIZE="$SIZE" \
	ITERS="$ITERS" \
	DO_PLOTS=0
