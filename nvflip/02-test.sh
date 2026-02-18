#!/bin/bash

set -e

REF="$(pwd)/nvflip/images/reference.png"
TEST="$(pwd)/nvflip/images/test.png"

# Run the CPU and GPU versions and compare the sample image.
./build/flip --reference $REF --test $TEST -b cpu
./build/flip-cuda --reference $REF --test $TEST -b gpu

CMP="$(compare -metric mse "cpu.png" "gpu.png" /dev/null 2>&1 | head -n 1 | cut -f 1 -d ' ')"
if [ "$(echo "print(${CMP} < 0.01)" | python3)" == "True" ] ; then
    echo -e "\x1b[32;1mPassed\x1b[m with \x1b[1m${CMP}\x1b[m\n"
else
    echo -e "\x1b[31;1mFAILED\x1b[m with \x1b[1m${CMP}\x1b[m\n"
    exit 2
fi
