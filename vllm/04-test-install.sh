#!/usr/bin/env bash
# shellcheck disable=2317,2329
. "$(dirname "$0")"/../util/prelude.sh

source "${SCRIPT_DIR}/util/env.sh"
source "${SCALE_VALIDATION}/util/checks.sh"

# What 03-install-vllm.sh installed, checked without a GPU.
check_import_vllm() {
    python -c "import vllm"
}

# SCALE's Triton backend registers with Triton as "scale" (redscale's test/triton_scale/compile.sh checks the same).
check_triton_scale() {
    python -c "from triton.backends import backends; assert 'scale' in backends, sorted(backends)"
}

check "import vllm" check_import_vllm
# 03-install-vllm.sh installs the backend when SCALE ships it, which SCALE for AMD GPUs does: there, missing fails.
if [[ "${SCALE_ENV:-}" == gfx* ]]; then
    check "Triton has SCALE's backend" check_triton_scale
fi
check_exit
