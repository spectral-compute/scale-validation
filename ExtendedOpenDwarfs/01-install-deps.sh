#!/bin/bash
set -ETeuo pipefail

cd ExtendedOpenDwarfs

export LC_ALL=C
export LANG=C

# Some hosts don't have libtool (hence libtoolize) installed system-wide,
# and we can't apt-install it there without root. It's managed via pixi
# instead (see pixi.toml, alongside R). Each Spectral Compute host
# provisions independently (no shared filesystem), so pixi itself may or
# may not already be present -- install it locally (no root required) if
# missing, rather than silently skipping activation and reproducing the
# exact autoreconf/libtoolize failure this exists to prevent.
PIXI_BIN=""
if command -v pixi >/dev/null 2>&1; then
	PIXI_BIN="pixi"
elif [[ -x "${HOME}/.pixi/bin/pixi" ]]; then
	PIXI_BIN="${HOME}/.pixi/bin/pixi"
else
	echo "pixi not found on this host -- installing locally into ~/.pixi (no root required)"
	curl -fsSL https://pixi.sh/install.sh | sh
	if [[ -x "${HOME}/.pixi/bin/pixi" ]]; then
		PIXI_BIN="${HOME}/.pixi/bin/pixi"
	else
		echo "warning: pixi install did not produce ${HOME}/.pixi/bin/pixi -- continuing without it" >&2
	fi
fi

if [[ -n "$PIXI_BIN" && -f "$(pwd)/pixi.toml" ]]; then
	eval "$("$PIXI_BIN" shell-hook --manifest-path "$(pwd)/pixi.toml")"

	# aclocal/autoreconf stay the SYSTEM binaries even when libtool itself
	# only comes from pixi (some hosts have libtool solely via pixi, but
	# automake/aclocal system-wide) -- point aclocal at pixi's libtool.m4
	# and friends explicitly, or autoreconf fails with "Libtool library
	# used but 'LIBTOOL' is undefined" even though libtoolize itself
	# resolves fine on PATH.
	PIXI_ACLOCAL_DIR="$(pwd)/.pixi/envs/default/share/aclocal"
	if [[ -d "$PIXI_ACLOCAL_DIR" ]]; then
		export ACLOCAL_PATH="${PIXI_ACLOCAL_DIR}${ACLOCAL_PATH:+:$ACLOCAL_PATH}"
	fi
fi


# pixi's shell-hook above exports its own HOST (a conda build triplet,
# e.g. x86_64-conda-linux-gnu) -- this must be set unconditionally
# (not ${HOST:-...}) to override that, since HOST is already non-empty
# by this point and the :- fallback would never trigger otherwise.
export HOST="$(hostname -s)"
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
