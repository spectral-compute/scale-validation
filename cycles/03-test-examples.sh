#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

FAILURES=()
for EXAMPLE in cube_surface cube_volume monkey sphere_bump; do
    IN="./cycles/examples/scene_${EXAMPLE}.xml"
    CPU_OUT="./${EXAMPLE}_cpu.png"
    CUDA_OUT="./${EXAMPLE}_cuda.png"

    set +e

    log "Rendering ${EXAMPLE} on CPU"

    if ! /usr/bin/time -f 'Time: %e' "./install/cycles" "${IN}" --device CPU --output "${CPU_OUT}"; then
        FAILURES+=("CPU:${EXAMPLE}")
        log "FAILED to run on CPU"
        continue
    fi

    echo -e "Rendering \x1b[1m${EXAMPLE}\x1b[m with \x1b[32;1mCUDA\x1b[m"

    if ! /usr/bin/time -f 'Time: %e' "./install/cycles" "${IN}" --device CUDA --output "${CUDA_OUT}"; then
        FAILURES+=("CUDA:${EXAMPLE}")
        log "FAILED to run with CUDA"
        continue
    fi

    set -e

    # The volume's edge pixels differ more between the CPU and GPU kernels: 0.016 on NVIDIA (v5.2.0).
    LIMIT=0.01
    if [ "${EXAMPLE}" == "cube_volume" ]; then
        LIMIT=0.03
    fi

    CMP="$(compare -metric mse "${CPU_OUT}" "${CUDA_OUT}" /dev/null 2>&1 | head -n 1 | cut -f 1 -d ' ')"
    if [ "$(echo "print(${CMP} < ${LIMIT})" | python3)" == "True" ]; then
        log "Passed with difference of ${CMP}"
    else
        FAILURES+=("CUDA:${EXAMPLE}")
        log "FAILED with ${CMP}\n"
    fi
done

for T in "${FAILURES[@]}"; do
    log "Failed: ${T}"
done
if [ "${#FAILURES[@]}" != "0" ]; then
    exit 1
fi
