#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source .venv/bin/activate

echo "torch==$(python -c 'import torch; print(torch.__version__)')" >constraints.txt

# Not a dependency of a source-built torch, but SGLang imports it everywhere.
python -m pip install -c constraints.txt "triton==$(cat pytorch/.ci/docker/triton_version.txt)"

# SGLang's own dependency list (with the diffusion extra, which its kernel tests
# import), minus what this test builds itself and the wheels of prebuilt NVIDIA
# device code, which can't run under SCALE. Tests that need the latter fail, and
# show what's missing.
python - sglang/python/pyproject.toml >requirements.txt <<'EOF'
import re
import sys
import tomllib

SKIP = {
    # Built by this test, or not needed (and pinned to another torch).
    "torch", "torchvision", "torchaudio", "torchcodec", "sglang-kernel",
    # Prebuilt NVIDIA device code.
    "cuda-tile", "flash-attn-4", "humming-kernels", "nvidia-cutlass-dsl",
    "nvidia-mathdx", "nvshmem4py-cu13", "quack-kernels", "sgl-deep-ep",
    "sgl-deep-gemm", "tilelang", "tokenspeed-mla", "torch-memory-saver",
    "nvidia-modelopt", "st-attn", "vsa",
}

with open(sys.argv[1], "rb") as f:
    project = tomllib.load(f)["project"]
deps = project["dependencies"] + project["optional-dependencies"]["diffusion"]
for dep in deps:
    name = re.match(r"[A-Za-z0-9._-]+", dep).group(0)
    if re.sub(r"[-_.]+", "-", name).lower() not in SKIP:
        # Drop extras like [cu13], which pull in NVIDIA's CUDA libraries.
        print(re.sub(r"\[cu[0-9]+\]", "", dep))
EOF
python -m pip install -c constraints.txt -r requirements.txt pytest tabulate

# The Rust extensions are optional, and would need a Rust toolchain.
python -m pip install "setuptools>=61" "setuptools-scm>=8" wheel
SGLANG_BUILD_RUST_EXTS=none python -m pip install --no-build-isolation --no-deps -v ./sglang/python

# FlashInfer's runtime-compiled kernels put its own CCCL (3.x) ahead of the
# toolkit's, and it needs driver APIs SCALE doesn't have yet. Move it aside, so
# they build against SCALE's.
if [[ -n "${SCALE_ENV:-}" ]]; then
    flashinfer_data="$(python -c 'import flashinfer, os; print(os.path.dirname(flashinfer.__file__))')/data"
    mv "${flashinfer_data}/cccl" "${flashinfer_data}/cccl.vendored"
fi

python -c 'import sglang; print(sglang.__version__)'
