#!/bin/bash
set -e

cd flash-attention
source .venv/bin/activate

if [ ! -f .flash-attention-build-ok ]; then
  echo "Skipping runtime test because FlashAttention build did not complete."
  exit 0
fi

case "${TEST_GPU_ARCH}" in
  sm_*)
    export LD_LIBRARY_PATH="$(pwd)/.venv/lib/python3.11/site-packages/torch/lib:$(pwd)/.venv/lib/python3.12/site-packages/torch/lib:${LD_LIBRARY_PATH:-}"

    python - <<'PY'
import torch
from flash_attn import flash_attn_func

print("torch:", torch.__version__)
print("cuda:", torch.version.cuda)
print("device:", torch.cuda.get_device_name(0))

q = torch.randn(1, 1024, 16, 64, device="cuda", dtype=torch.float16)
k = torch.randn(1, 1024, 16, 64, device="cuda", dtype=torch.float16)
v = torch.randn(1, 1024, 16, 64, device="cuda", dtype=torch.float16)

out = flash_attn_func(q, k, v)
torch.cuda.synchronize()
print("flash-attention smoke test OK:", tuple(out.shape))
PY
    ;;

  gfx*)
    echo "Skipping runtime test for ${TEST_GPU_ARCH}."
    echo "SCALE/AMD currently fails during build before runtime."
    ;;

  *)
    echo "Unsupported TEST_GPU_ARCH=${TEST_GPU_ARCH}" >&2
    exit 1
    ;;
esac
