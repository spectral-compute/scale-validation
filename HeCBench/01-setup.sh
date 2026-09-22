#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

OUT_DIR="$(realpath .)"
SRC_DIR="${SRC_DIR:-${OUT_DIR}/HeCBench}"

USER_PRESET_PATH="$SRC_DIR/CMakeUserPresets.json"
TEST_GPU_ARCH="${SCALE_ENV:-${CUDAARCHS}}"

if [[ -z "${TEST_MODE:-}" ]] && [[ "${SCALE_ENV:-}" == *gfx* ]]; then
    export TEST_MODE="scale-amd"
elif [[ -z "${TEST_MODE:-}" ]]; then
    export TEST_MODE="scale-nvidia"
fi

# If jq fails, the tmp files we use might stick around. Clean them up
trap 'rm -f "${tmp-}"' EXIT


cat << EOF > "$USER_PRESET_PATH"
{
    "version": 3,

    "configurePresets": []
}
EOF

# Create configure and build presets for available architectures that aren't already
# provided by HeCBench presets, and obviously the SCALE targets.
case "${TEST_MODE}" in
	scale-amd|scale-nvidia|nvcc-nvidia)
		# Expect CUDAARCHS like 80, 86, 90 — not sm_80
		CUDA_ARCH_NUM="${CUDAARCHS#sm_}"

		case "$TEST_TOOLCHAIN" in
			scale) PRESET_NAME="scale-cuda-sm$CUDA_ARCH_NUM"; PRESET_DESC="SCALE benchmark target" ;;
			nvcc)  PRESET_NAME="cuda-sm$CUDA_ARCH_NUM"; PRESET_DESC="NVIDIA CUDA benchmark target" ;;
		esac

		tmp="$(mktemp)"
		jq --arg name "$PRESET_NAME" \
			--arg desc "$PRESET_DESC" \
			--arg arch "$CUDA_ARCH_NUM"\
			'.configurePresets += [{
				"name": $name,
				"displayName": $desc,
				"inherits": "default",
				"cacheVariables": {
					"CMAKE_CUDA_COMPILER": "nvcc",
					"HECBENCH_ENABLE_CUDA": "ON",
					"HECBENCH_ENABLE_HIP": "OFF",
					"HECBENCH_ENABLE_SYCL": "OFF",
					"HECBENCH_ENABLE_OPENMP": "OFF",
					"HECBENCH_CUDA_ARCH": $arch
				}
			}]' "$USER_PRESET_PATH" > "$tmp" && mv "$tmp" "$USER_PRESET_PATH"
		;;

	hip-amd)
		# Per-arch additions overlaid on the generated HIP preset. Value is a JSON
		# object deep-merged into the preset, so it can touch cacheVariables,
		# environment, or any other preset field.
		declare -A HIP_ARCH_EXTRAS=(
			# Write per-arch overrides here, e.g.:
			# [gfx942]='{"cacheVariables":{"CMAKE_HIP_FLAGS_RELEASE":"-O3 -ffast-math"}}'
			# [gfx1201]='{"cacheVariables":{"CMAKE_HIP_FLAGS":"-munsafe-fp-atomics"}}'
		)

		extras='{}'
		if [[ -v HIP_ARCH_EXTRAS[$TEST_GPU_ARCH] ]]; then
			extras="${HIP_ARCH_EXTRAS[$TEST_GPU_ARCH]}"
		fi

		tmp="$(mktemp)"
		jq --arg name "hip-$TEST_GPU_ARCH" \
		--arg arch "$TEST_GPU_ARCH" \
		--argjson extras "$extras" \
		'.configurePresets += [ ({
			"name": $name,
			"displayName": $arch,
			"inherits": "default",
			"cacheVariables": {
				"CMAKE_HIP_COMPILER": "$env{ROCM_PATH}/llvm/bin/clang++",
				"CMAKE_HIP_PLATFORM": "amd",
				"CMAKE_HIP_ARCHITECTURES": $arch,
				"HECBENCH_ENABLE_CUDA": "OFF",
				"HECBENCH_ENABLE_HIP": "ON",
				"HECBENCH_ENABLE_SYCL": "OFF",
				"HECBENCH_ENABLE_OPENMP": "OFF",
				"HECBENCH_HIP_ARCH": $arch
			}
		} * $extras) ]' "$USER_PRESET_PATH" > "$tmp" && mv "$tmp" "$USER_PRESET_PATH"
		;;

	*)
		echo "Unrecognised test mode: $TEST_MODE"
		exit 1
		;;
esac

echo "Wrote new CMake user presets"
cat "$USER_PRESET_PATH"


(
    cd "$SRC_DIR"

    # Compilation Failures:

    # SCALE
    # (These will steadily be addressed.)
	if [[ "$TEST_TOOLCHAIN" == "scale" ]]; then
		# - All
		sed -i -E 's/^([[:space:]]*)(prefetch)[[:space:]]*$/\1#\2  # SCALE: known failure/' src/CMakeLists.txt

		# - On AMD
		if [[ "$TEST_MODE" == "scale-amd" ]]; then
			# > gfx1201
			if [[ "$TEST_GPU_ARCH" == "gfx1201" ]]; then
				sed -i /blas-fp8gemm/d src/CMakeLists.txt
				sed -i -E '/^[[:space:]]*attentionMultiHeadKVCache[[:space:]]*$/d' src/CMakeLists.txt
			fi

			# > gfx90a
			if [[ "$TEST_GPU_ARCH" == "gfx90a" ]]; then
				sed -i -E '/^[[:space:]]*mlp[[:space:]]*$/d' src/CMakeLists.txt
			fi

			# > gfx942
			if [[ "$TEST_GPU_ARCH" == "gfx942" ]]; then
				sed -i -E '/^[[:space:]]*mlp[[:space:]]*$/d' src/CMakeLists.txt
			fi
		fi

		# - On NVIDIA
		if [[ "$TEST_MODE" == "scale-nvidia" ]]; then
			# > sm_120
			if [[ "$TEST_GPU_ARCH" == "sm_120" ]]; then
				sed -i -E '/^[[:space:]]*qkv[[:space:]]*$/d' src/CMakeLists.txt
				sed -i /d3q19-bgk/d src/CMakeLists.txt
				sed -i /quant3MatMul/d src/CMakeLists.txt
				sed -i /sobol/d src/CMakeLists.txt

				# "error: use of undeclared identifier '__NV_ATOMIC_RELAXED'"
				sed -i -E '/^[[:space:]]*michalewicz[[:space:]]*$/d' src/CMakeLists.txt
				sed -i -E '/^[[:space:]]*graphB\+[[:space:]]*$/d' src/CMakeLists.txt
				sed -i -E '/^[[:space:]]*scatter[[:space:]]*$/d' src/CMakeLists.txt
				sed -i -E '/^[[:space:]]*hausdorff[[:space:]]*$/d' src/CMakeLists.txt
				sed -i -E '/^[[:space:]]*lebesgue[[:space:]]*$/d' src/CMakeLists.txt
				sed -i -E '/^[[:space:]]*atomicCAS[[:space:]]*$/d' src/CMakeLists.txt

				# Link error on isfinite
				sed -i -E '/^[[:space:]]*permute[[:space:]]*$/d' src/CMakeLists.txt

			fi
		fi
	fi


	if [[ "$TEST_MODE" == "hip-amd" ]]; then
		# - RDNA (gfx10xx+): ROCm 7.2.3's backend lowers __syncthreads_and to a
		#   wave_shr DPP op that does not exist on GFX10+, then rejects its own output:
		#   "Invalid dpp_ctrl value: wavefront shifts are not supported on GFX10+".
		#   Confirmed broken on gfx1030/gfx1100/gfx1201, fine on gfx906/gfx90a/gfx942.
		if [[ "$TEST_GPU_ARCH" == gfx1* ]]; then
			sed -i -E '/^[[:space:]]*nms[[:space:]]*$/d' src/CMakeLists.txt
		fi

		if [[ "$TEST_GPU_ARCH" == "gfx1201" ]]; then
			sed -i -E '/^[[:space:]]*addBiasQKV[[:space:]]*$/d' src/CMakeLists.txt
			sed -i -E '/^[[:space:]]*dp4a[[:space:]]*$/d' src/CMakeLists.txt
		fi
	fi
)
