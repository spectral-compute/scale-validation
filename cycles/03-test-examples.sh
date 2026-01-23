#!/bin/bash

set -e

RETCODE=0
BROKEN=

for EXAMPLE in cube_surface cube_volume monkey sphere_bump ; do
    IN="./cycles/examples/scene_${EXAMPLE}.xml"
    CPU_OUT="./${EXAMPLE}_cpu.png"
    CUDA_OUT="./${EXAMPLE}_cuda.png"

    set +e

    echo -e "Rendering \x1b[1m${EXAMPLE}\x1b[m on \x1b[34;1mCPU\x1b[m"
    /usr/bin/time -f 'Time: %e' "./install/cycles" "${IN}" --device CPU --output "${CPU_OUT}"
    if [ "$?" != "0" ] ; then
        BROKEN="${BROKEN}\n${EXAMPLE}"
        RETCODE=2
        echo -e "\x1b[31;1mFAILED\x1b[m to run on \x1b[1mCPU\x1b[m\n"
        continue
    fi

    echo -e "Rendering \x1b[1m${EXAMPLE}\x1b[m with \x1b[32;1mCUDA\x1b[m"
    /usr/bin/time -f 'Time: %e' "./install/cycles" "${IN}" --device CUDA --output "${CUDA_OUT}"
    if [ "$?" != "0" ] ; then
        BROKEN="${BROKEN}\n${EXAMPLE}"
        RETCODE=2
        echo -e "\x1b[31;1mFAILED\x1b[m to run with \x1b[1mCUDA\x1b[m\n"
        continue
    fi

    set -e

    CMP="$(compare -metric mse "${CPU_OUT}" "${CUDA_OUT}" /dev/null 2>&1 | head -n 1 | cut -f 1 -d ' ')"
    if [ "$(echo "print(${CMP} < 0.01)" | python3)" == "True" ] ; then
        echo -e "\x1b[32;1mPassed\x1b[m with \x1b[1m${CMP}\x1b[m\n"
    else
        BROKEN="${BROKEN}\n${EXAMPLE}"
        RETCODE=2
        echo -e "\x1b[31;1mFAILED\x1b[m with \x1b[1m${CMP}\x1b[m\n"
    fi
done

echo -e "${BROKEN}"
exit $RETCODE
