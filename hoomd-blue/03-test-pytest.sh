#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Run each device-parameterised test only on the GPU, and fail rather than skip if no GPU is found.
export _HOOMD_SKIP_CPU_TESTS_WHEN_GPUS_PRESENT_=1
export _HOOMD_REQUIRE_GPU_TESTS_IN_GPU_BUILDS_=1
export PYTHONPATH="$(realpath install)"

venv/bin/python -c 'import hoomd; print("available:", hoomd.device.GPU.get_available_devices())'
venv/bin/python -m pytest --pyargs hoomd -v -ra -p no:cacheprovider
