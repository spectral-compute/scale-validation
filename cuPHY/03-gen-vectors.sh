#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# cuPHY's tests read HDF5 test vectors made by Aerial's 5GModel: compiled MATLAB, which runs on the free
# MATLAB Runtime R2023a with Python 3.8-3.10. Set CUPHY_TEST_VECTORS to a directory of ready-made vectors
# to skip this, or MATLAB_RUNTIME to an existing R2023a install (the directory containing runtime/).
if [[ -n "${CUPHY_TEST_VECTORS:-}" ]]; then
    ln -sfn "${CUPHY_TEST_VECTORS}" tv
    exit 0
fi

if [[ -z "${MATLAB_RUNTIME:-}" ]]; then
    MATLAB_RUNTIME="$(realpath .)/mcr/R2023a"
    if [[ ! -d "${MATLAB_RUNTIME}" ]]; then
        curl -fsSL -o mcr.zip \
            https://ssd.mathworks.com/supportfiles/downloads/R2023a/Release/8/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2023a_Update_8_glnxa64.zip
        mkdir -p mcr-installer
        unzip -q -o mcr.zip -d mcr-installer
        mcr-installer/install -agreeToLicense yes -destinationFolder "$(realpath .)/mcr"
        rm -rf mcr.zip mcr-installer
    fi
fi

# A Python the runtime supports, with the 5GModel wheel (an LFS object 00-clone.sh skipped).
WHEEL_DIR=aerial/5GModel/aerial_mcore/aerial_pkg/dist
if ! unzip -tq "${WHEEL_DIR}"/aerial_mcore-*.whl >/dev/null 2>&1; then
    git -C aerial lfs pull --include="${WHEEL_DIR#aerial/}/*"
fi
python3 -m venv uv-venv
uv-venv/bin/pip install -q uv
uv-venv/bin/uv venv -q --python 3.10 py310
uv-venv/bin/uv pip install -q --python py310/bin/python numpy pyyaml "${MATLAB_RUNTIME}/toolbox/compiler_sdk/pysdk_py" \
    "${WHEEL_DIR}"/aerial_mcore-*.whl

export LD_LIBRARY_PATH="${MATLAB_RUNTIME}/runtime/glnxa64:${MATLAB_RUNTIME}/bin/glnxa64:${MATLAB_RUNTIME}/sys/os/glnxa64:${MATLAB_RUNTIME}/extern/bin/glnxa64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export REGRESSION_MODE=2 # Test vectors only, compact set.

# Not dlmix/ulmix: ~100 GB each, and only multi-cell variations of these.
mkdir -p tv
for c in ssb pdcch pdsch csirs prach pucch pusch srs simplex bfw; do
    log "Generating ${c} test vectors"
    rm -rf "tvgen-${c}"
    mkdir -p "tvgen-${c}/GPU_test_input" # The BFW generator doesn't create it.
    (cd "tvgen-${c}" && ../py310/bin/python ../aerial/5GModel/aerial_mcore/examples/example_5GModel_regression.py "${c}")
    mv "tvgen-${c}"/GPU_test_input/*CUPHY*.h5 tv/ 2>/dev/null || true
    rm -rf "tvgen-${c}"
done
[[ -n "$(ls tv)" ]]
