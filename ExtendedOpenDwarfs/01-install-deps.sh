#!/bin/bash
set -ETeuo pipefail

cd ExtendedOpenDwarfs

export LC_ALL=C
export LANG=C

export HOST="${HOST:-$(hostname -s)}"
export LSB_SRC_DIR="${LSB_SRC_DIR:-$(pwd)/external/liblsb-src}"
export LSB_INSTALL_ROOT="${LSB_INSTALL_ROOT:-$(pwd)/external/liblsb-install/${HOST}}"
export LSB_GIT_URL="${LSB_GIT_URL:-https://github.com/spcl/liblsb.git}"

echo "Installing ExtendedOpenDwarfs dependencies"
echo "  LSB_SRC_DIR=${LSB_SRC_DIR}"
echo "  LSB_INSTALL_ROOT=${LSB_INSTALL_ROOT}"

mkdir -p "$(dirname "${LSB_SRC_DIR}")"

if [[ ! -d "${LSB_SRC_DIR}/.git" ]]; then
	git clone "${LSB_GIT_URL}" "${LSB_SRC_DIR}"
fi

cd "${LSB_SRC_DIR}"

make distclean >/dev/null 2>&1 || true
rm -rf .deps .libs tests/.deps tests/.libs

python3 - <<'PATCH_LIBLSB'
from pathlib import Path

p = Path("configure.ac")
s = p.read_text()
s = s.replace("LT_INIT[disable-shared]", "LT_INIT([disable-shared])")
p.write_text(s)

for name in ("hrtimer/sanity-check.c", "hrtimer/getres.c"):
    p = Path(name)
    s = p.read_text()
    marker = "#include <stdint.h>\nuint64_t liblsb_g_timerfreq = 1;\n"
    if "liblsb_g_timerfreq = 1" not in s:
        p.write_text(marker + s)

print("Patched liblsb configure.ac and hrtimer timer probes")
PATCH_LIBLSB

autoreconf -fi

env CC=/usr/bin/gcc CXX=/usr/bin/g++ \
	./configure \
		--prefix="${LSB_INSTALL_ROOT}" \
		--without-mpi \
		--without-papi

make CC=/usr/bin/gcc CXX=/usr/bin/g++
make install

mkdir -p "${LSB_INSTALL_ROOT}"
touch "${LSB_INSTALL_ROOT}/.installed"
