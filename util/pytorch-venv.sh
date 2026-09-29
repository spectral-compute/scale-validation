# Reuse the pytorch test's venv (like openmpi). Run the pytorch test first, same workdir.

PYTORCH_DIR="$(realpath ../)/pytorch/pytorch"
PYTORCH_VENV="${PYTORCH_DIR}/.venv"

if [ ! -e "${PYTORCH_VENV}" ] ; then
    echo "Please build the PyTorch third party project first. Use the same working directory." 1>&2
    exit 1
fi

_purelib() {
    "$1" -c 'import sysconfig; print(sysconfig.get_path("purelib"))'
}

create_pytorch_venv() {
    python3 -m venv .venv
    # addsitedir so its .pth files (e.g. distutils shim) load too.
    echo "import site; site.addsitedir('$(_purelib "${PYTORCH_VENV}/bin/python")')" \
        > "$(_purelib .venv/bin/python)/pytorch.pth"
}

pytorch_constraints() {
    echo "torch==$(.venv/bin/python -c 'import torch; print(torch.__version__)')" > "$1"
}
