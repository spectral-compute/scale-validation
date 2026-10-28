#!/usr/bin/env bash
# Install a package from outside the distro package manager, for an `ext` entry in a
# `.dependencies` file. Takes the entry's `<name>=<version>` spec as its only argument.
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <name>=<version>" >&2
    exit 1
fi

ARCH="$(uname -m)"

# Download a URL into the current directory, failing on HTTP errors.
fetch() {
    curl -fsSL --proto '=https' --tlsv1.2 -O "$1"
}

# Install a specific version of CMake, using upstream's installer scripts.
install_cmake() {
    local version="$1" sha256
    case "${version}-${ARCH}" in
    3.31.12-x86_64) sha256=04c85c742484a490ee9deabab70c0af61b2592f99f768e87743f078366c1bbe2 ;;
    4.0.3-x86_64) sha256=1d15a366ce6a5191f26ca23b3c7ae6f5690ffa63fa87ffbea4b92fb27e7c6170 ;;
    *)
        echo "No pinned hash for CMake ${version} on ${ARCH}" >&2
        exit 1
        ;;
    esac

    if [[ "$(cmake --version 2>/dev/null | head -n1)" == "cmake version ${version}" ]]; then
        echo "CMake ${version} is already installed"
        return
    fi

    local script="cmake-${version}-linux-${ARCH}.sh"
    fetch "https://github.com/Kitware/CMake/releases/download/v${version}/${script}"
    echo "${sha256}  ${script}" | sha256sum -c --quiet -

    chmod +x "$script"
    "./$script" --skip-license --prefix=/usr
    hash -r
    cmake --version | head -n1
}

# Install rustup as stressedtuna, and set its default toolchain. image_graph.py adds
# ~stressedtuna/.cargo/bin to the image's PATH.
install_rust() {
    local channel="$1" rustup_version="1.29.1"
    case "${rustup_version}-${ARCH}" in
    1.29.1-x86_64) sha256=dda7234360b7f578ca8b0ddcb80145646fa61a67c1720a5abc7051b35c9fcb71 ;;
    *)
        echo "No pinned hash for rustup ${rustup_version} on ${ARCH}" >&2
        exit 1
        ;;
    esac

    fetch "https://static.rust-lang.org/rustup/archive/$rustup_version/$ARCH-unknown-linux-gnu/rustup-init"
    echo "${sha256}  rustup-init" | sha256sum -c --quiet -
    chmod o=rx . -R
    sudo -u stressedtuna ./rustup-init --default-toolchain "$channel" -y
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT
cd "${WORKDIR}"

SPEC="$1"
case "${SPEC}" in

cmake=3.31) install_cmake 3.31.12 ;;
cmake=4.0) install_cmake 4.0.3 ;;

rust=stable | rust=beta | rust=nightly | rust=[0-9]*.[0-9]*) install_rust "${SPEC#rust=}" ;;

*)
    echo "Unrecognised ext spec: ${SPEC}" >&2
    exit 1
    ;;
esac
