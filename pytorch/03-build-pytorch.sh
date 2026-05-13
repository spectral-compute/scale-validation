#!/bin/bash
set -ETeuo pipefail
shopt -s nullglob

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
OUT_DIR="$(realpath .)"
SRCDIR="${OUT_DIR}/pytorch"
BUILDDIR="${SRCDIR}/build"

VISIONDIR="${OUT_DIR}/vision"
VISION_REF="${VISION_REF:-v0.24.0}"

PYBIN=python

CUDAARCHS="${CUDAARCHS:-89}"
cudaarch_to_torch_arch() {
    local arch="$1"
    local major="${arch:0:${#arch}-1}"
    local minor="${arch: -1}"
    echo "${major}.${minor}"
}

cd "${SRCDIR}"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi

source .venv/bin/activate

${PYBIN} -V
${PYBIN} -m pip -V
${PYBIN} -m pip install --upgrade pip wheel
${PYBIN} -m pip install "setuptools==81.0.0"
${PYBIN} -m pip install pyyaml typing_extensions jinja2 numpy

cd "${BUILDDIR}/pytorch"

export CC="${CC:-/usr/bin/gcc}"
export CXX="${CXX:-/usr/bin/g++}"
export CUDAHOSTCXX="${CXX}"

export CFLAGS="\
    -march=native \
    -mtune=native \
    -Wno-inconsistent-missing-destructor-override \
    -Wno-deprecated-copy-with-user-provided-dtor \
    -Wno-dangling-reference \
    -Wno-redundant-move
"
export CXXFLAGS="${CFLAGS}"
export _GLIBCXX_USE_CXX11_ABI=TRUE
export CUDNN_INCLUDE_DIR=/usr/include
export CUDNN_LIB_DIR=/usr/lib
export CUDAARCHS
export TORCH_CUDA_ARCH_LIST="$(cudaarch_to_torch_arch "$CUDAARCHS")"
export USE_CUDA=ON
export USE_CUDNN=OFF
export USE_CUFILE=OFF
export CAFFE2_USE_CUDNN=OFF
export USE_CUSPARSELT=OFF
export USE_NCCL=OFF
export USE_DISTRIBUTED=ON
export USE_FAKELOWP=OFF
export USE_FBGEMM=OFF
export USE_FFMPEG=OFF
export USE_GFLAGS=OFF
export USE_GLOG=OFF
export USE_ITT=OFF
export USE_KINETO=OFF
export USE_LEVELDB=OFF
export USE_LMDB=OFF
export USE_MKLDNN=OFF
export USE_NUMPY=ON
export USE_OPENCV=OFF
export USE_ROCM=OFF
export BUILD_CAFFE2=ON
export BUILD_CAFFE2_OPS=ON
export BUILD_BINARY=OFF
export BUILD_TEST=OFF
export CMAKE_POLICY_VERSION_MINIMUM=3.5
export CMAKE_ARGS="-DBUILD_BINARY=OFF -DBUILD_TEST=OFF -DCMAKE_CUDA_ARCHITECTURES=${CUDAARCHS}"
export FORCE_CUDA=1
export MAX_JOBS="${MAX_JOBS:-$(nproc)}"

${PYBIN} setup.py build

# Install PyTorch into the active venv to build  torchvision against this exact version.
${PYBIN} setup.py install --skip-build

INSTALL_DIR="${BUILDDIR}/../install/"

# Install PyTorch into a staged root under install/
${PYBIN} setup.py install --root="${INSTALL_DIR}" --optimize=1 --skip-build

# Link the C++ API to a sensible place
function symlinkAllIn {
    local DST_DIR="${1:-}"
    local SRC_DIR="${2:-}"

    [[ -n "$DST_DIR" ]] || return 0
    [[ -d "$SRC_DIR" ]] || return 0

    mkdir -p "$DST_DIR"

    local F
    local B

    for F in "$SRC_DIR"/*; do
        [[ -e "$F" ]] || continue
        B="$(basename "$F")"
        ln -sfn "$F" "$DST_DIR/$B"
    done
}

PYVER="$(${PYBIN} --version | sed -E 's/Python ([0-9]+\.[0-9]+)\.[0-9]+/\1/')"
SRC="${INSTALL_DIR}/usr/lib/python${PYVER}/site-packages/torch"
DST="${INSTALL_DIR}/usr"

symlinkAllIn "${DST}/lib" "${SRC}/lib"
for D in "${SRC}/include/"* "${SRC}/include/torch/csrc/api/include/"*; do
    symlinkAllIn "${DST}/include/$(basename "${D}")" "${D}"
done

# Verify PyTorch from outside the source tree
cd /tmp
${PYBIN} - <<'PY'
import torch

print("torch:", torch.__version__)
print("torch:", torch.__file__)
print("cuda available:", torch.cuda.is_available())
print("torch cuda:", torch.version.cuda)

assert torch.cuda.is_available(), "CUDA is not available"
PY

cd "${OUT_DIR}"

# Remove any previously installed incompatible torchvision
${PYBIN} -m pip uninstall -y torchvision || true

${PYBIN} -m pip install --upgrade numpy pillow ninja
${PYBIN} -m pip install "setuptools==81.0.0"

if [[ ! -d "${VISIONDIR}" ]]; then
  git clone https://github.com/pytorch/vision.git "${VISIONDIR}"
fi

cd "${VISIONDIR}"
git fetch --all --tags
git checkout "${VISION_REF}"

# Build torchvision against the PyTorch installed in this venv
${PYBIN} -m pip install -v --no-build-isolation --no-deps -e .


# Verify PyTorch + torchvision
cd /tmp

${PYBIN} - <<'PY'
import torch
import torchvision

print("torch:", torch.__version__)
print("torch:", torch.__file__)
print("cuda available:", torch.cuda.is_available())
print("torch cuda:", torch.version.cuda)

if not torch.cuda.is_available():
    raise RuntimeError("CUDA is not available")

print("gpu:", torch.cuda.get_device_name(0))

print("torchvision:", torchvision.__version__)
print("torchvision:", torchvision.__file__)

from torchvision.ops import nms
print("torchvision.ops.nms: OK")
PY
