#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

source .venv/bin/activate

echo "torch==$(python -c 'import torch; print(torch.__version__)')" >constraints.txt

# As upstream's ROCm images do: the ROCm pyproject, with its runtime extras
# flattened (pip trips over their self-references), minus torch.
cp sglang/python/pyproject_other.toml sglang/python/pyproject.toml
python - sglang/python/pyproject.toml >requirements.txt <<'EOF'
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    project = tomllib.load(f)["project"]
extras = project["optional-dependencies"]
deps = list(project["dependencies"])
for group in ("runtime_base", "runtime_common", "srt_hip"):
    deps += [d for d in extras[group] if not d.startswith("sglang[")]
for dep in dict.fromkeys(deps):
    if dep != "torch":
        print(dep)
EOF
python -m pip install -c constraints.txt -r requirements.txt

python -m pip install "setuptools>=61" "setuptools-scm>=8" wheel
SGLANG_BUILD_RUST_EXTS=none python -m pip install --no-build-isolation --no-deps -v ./sglang/python

# Upstream builds aiter's kernels ahead of time on CDNA, and leaves them to JIT
# elsewhere, where the ahead-of-time build fails.
case "${TEST_GPU_ARCH}" in
gfx942 | gfx950) export PREBUILD_KERNELS=1 ;;
esac
cd aiter
GPU_ARCHS="${TEST_GPU_ARCH}" python -m pip install -c ../constraints.txt --no-build-isolation -v .

python -c 'import sglang; print(sglang.__version__)'
