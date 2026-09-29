#!/bin/bash

set -uo pipefail
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "${SCRIPT_DIR}/util/env.sh"
source "${SCRIPT_DIR}/../util/checks.sh"

# Skipped: dc (NCCL), cutlass_ops/ragged_device_ops (prebuilt kernels), fp_quantizer (fails on nvcc).
OPS=$(python - <<'PY'
from deepspeed.ops.op_builder.all_ops import ALL_OPS
skip = {"dc", "cutlass_ops", "ragged_device_ops", "fp_quantizer"}
print(" ".join(name for name, builder in sorted(ALL_OPS.items())
               if name not in skip and builder.is_compatible()))
PY
)

build_op() {
    python -c "
from deepspeed.ops.op_builder.all_ops import ALL_OPS
ALL_OPS['$1'].load(verbose=False)
print('built $1')
"
}

for op in ${OPS}; do
    check "build ${op}" build_op "${op}"
done

# As upstream CI: default set, then sequential (incl. evoformer attention).
run_ops_tests() {
    (cd DeepSpeed/tests && python -m pytest unit/ops --ignore=unit/ops/fp_quantizer -v -p no:randomly "$@")
}

check "op unit tests" run_ops_tests
check "op unit tests (sequential)" run_ops_tests -m sequential
check_exit
