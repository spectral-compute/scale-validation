#!/bin/bash
set -e

cd flash-attention

python3.11 -m venv .venv 2>/dev/null || python3 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
python -m pip install \
  'setuptools<82' \
  wheel \
  ninja \
  packaging \
  psutil \
  cmake \
  pytest \
  einops

python -m pip uninstall -y torch torchvision torchaudio || true
python -m pip install --force-reinstall \
  torch==2.11.0+cu129 \
  torchvision \
  torchaudio \
  --index-url https://download.pytorch.org/whl/cu129

python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda:", torch.version.cuda)
print("hip:", torch.version.hip)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device:", torch.cuda.get_device_name(0))
PY
