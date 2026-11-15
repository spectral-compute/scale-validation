#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# DEME's native HIP backend, for comparison.

# DEME's JIT kernels use the fixed-width integer types unqualified. Since ROCm 7.14, hipRTC only
# declares them in namespace __hip_internal, so pull them into the global namespace. Repeating a
# typedef of the same type is fine, so this is harmless on older ROCm.
F=DEM-Engine/src/DEM/VariableTypes.h
if ! grep -q __hip_internal "${F}"; then
    types=""
    for t in int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t; do
        types+="typedef __hip_internal::${t} ${t};\n"
    done
    sed -i "s/^namespace deme {$/#ifdef __HIPCC_RTC__\n${types}#endif\n\n&/" "${F}"
    grep -q 'typedef __hip_internal::uint16_t uint16_t;' "${F}"
fi

cmake -B build -S DEM-Engine \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_HIP=ON \
    -DCMAKE_HIP_ARCHITECTURES="${TEST_GPU_ARCH}" \
    -DCMAKE_PREFIX_PATH="${ROCM_PATH}" \
    -GNinja

ninja -C build
