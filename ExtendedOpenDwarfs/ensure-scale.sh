#!/usr/bin/env bash
#
# ensure_scale.sh
#
# Lives in scale-validation/ExtendedOpenDwarfs/, alongside 00-clone.sh,
# 01-install-deps.sh, etc. Ensures a given version of SCALE is installed
# as a sibling of the nested EOD checkout that 00-clone.sh creates (i.e.
# scale-validation/ExtendedOpenDwarfs/scale-<version>-Linux), matching the
# location setup-backends.sh's own default SCALE_ROOT computation expects
# -- one level above wherever this script lives, not tied to any
# particular git repo structure.
#
# Downloads and extracts the requested version if it isn't already
# present. Different versions install side by side (e.g.
# scale-1.7.1-Linux, scale-1.7.2-Linux), so switching SCALE_VERSION
# between runs -- for regression testing across SCALE releases -- doesn't
# require re-downloading a version you've already fetched before, and
# never overwrites a different version already on disk.
#
# Available versions can be listed at https://pkgs.scale-lang.com/tar/ --
# as of writing: 1.5.0, 1.5.1, 1.6.0, 1.6.1, 1.7.0, 1.7.1, 1.7.2, or the
# moving alias "latest" (which always re-downloads, since its actual
# version isn't known until after fetching).
#
# On success, writes the absolute path of the resolved SCALE install to
# <SCALE_INSTALL_DIR>/.ensure_scale_last_root -- this is how
# run_regression_fleet.sh (or any other caller) picks up SCALE_ROOT for
# whichever version was just ensured, without needing to parse this
# script's human-readable log output.
#
# Usage (from scale-validation/ExtendedOpenDwarfs/):
#   ./ensure_scale.sh
#   SCALE_VERSION=1.7.1 ./ensure_scale.sh
#   SCALE_VERSION=1.6.1 ./ensure_scale.sh   # a different version, installed alongside, not overwriting the above
#
# Environment variables (all optional):
#
#   SCALE_VERSION
#       Version to install, e.g. "1.7.2", or "latest" for whatever the
#       moving latest-alias currently points to. Default: "latest"
#
#   SCALE_INSTALL_DIR
#       Directory to install SCALE into. Default: the directory this
#       script itself lives in (scale-validation/ExtendedOpenDwarfs/) --
#       i.e. a sibling of the nested EOD checkout 00-clone.sh creates
#       there, matching setup-backends.sh's own default SCALE_ROOT parent
#       directory.
#
#   SCALE_TARBALL_URL
#       Full override of the download URL, if you need something other
#       than the standard
#       https://pkgs.scale-lang.com/tar/scale-<version>-amd64.tar.xz
#       naming -- e.g. to fetch a scale-free-* edition instead. When set,
#       SCALE_VERSION is still used for the installed directory's expected
#       name / idempotency check, so set both together if you use this.
#
#   SCALE_FORCE_REINSTALL
#       1 to re-download and re-extract even if this exact version
#       already appears to be installed. Default: 0
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${SCALE_VERSION:=latest}"
: "${SCALE_INSTALL_DIR:=$SCRIPT_DIR}"
: "${SCALE_FORCE_REINSTALL:=0}"

if [[ -z "${SCALE_TARBALL_URL:-}" ]]; then
	SCALE_TARBALL_URL="https://pkgs.scale-lang.com/tar/scale-${SCALE_VERSION}-amd64.tar.xz"
fi

MARKER_FILE="${SCALE_INSTALL_DIR}/.ensure_scale_last_root"

# For a pinned (non-"latest") version we can predict the installed
# directory's expected name up front and skip the download entirely if
# it's already there. "latest" is a moving target -- its actual version
# isn't known until after downloading -- so it always re-checks.
PREDICTED_NAME=""
if [[ "$SCALE_VERSION" != "latest" ]]; then
	PREDICTED_NAME="scale-${SCALE_VERSION}-Linux"

	if [[ "$SCALE_FORCE_REINSTALL" != "1" ]] && [[ -x "${SCALE_INSTALL_DIR}/${PREDICTED_NAME}/bin/scaleenv" ]]; then
		echo "SCALE ${SCALE_VERSION} already present at ${SCALE_INSTALL_DIR}/${PREDICTED_NAME} -- skipping install"
		echo "(set SCALE_FORCE_REINSTALL=1 to force a fresh download/extract)"
		echo "${SCALE_INSTALL_DIR}/${PREDICTED_NAME}" > "$MARKER_FILE"
		exit 0
	fi
fi

echo "Installing SCALE (version: ${SCALE_VERSION}) into ${SCALE_INSTALL_DIR}"
echo "  source: ${SCALE_TARBALL_URL}"

mkdir -p "$SCALE_INSTALL_DIR"
cd "$SCALE_INSTALL_DIR"

TMP_TARBALL="$(mktemp --tmpdir "scale-${SCALE_VERSION}-amd64.XXXXXX.tar.xz")"
BEFORE_LISTING="$(mktemp)"
AFTER_LISTING="$(mktemp)"
trap 'rm -f "$TMP_TARBALL" "$BEFORE_LISTING" "$AFTER_LISTING"' EXIT

echo "Downloading tarball..."
wget -q -O "$TMP_TARBALL" "$SCALE_TARBALL_URL"

# Snapshot directory contents before/after extraction to detect exactly
# what the tarball added, regardless of its internal directory name.
find . -maxdepth 1 -mindepth 1 -printf '%f\n' | sort > "$BEFORE_LISTING"

echo "Extracting..."
tar xf "$TMP_TARBALL"

find . -maxdepth 1 -mindepth 1 -printf '%f\n' | sort > "$AFTER_LISTING"

NEW_ENTRIES="$(comm -13 "$BEFORE_LISTING" "$AFTER_LISTING")"

EXTRACTED_DIR=""
while IFS= read -r entry; do
	[[ -n "$entry" ]] || continue
	if [[ -d "$entry" ]]; then
		EXTRACTED_DIR="$entry"
		break
	fi
done <<< "$NEW_ENTRIES"

if [[ -z "$EXTRACTED_DIR" ]]; then
	echo "error: could not determine which directory the tarball extracted (new entries: ${NEW_ENTRIES:-none})" >&2
	exit 1
fi

echo "Extracted to: ${SCALE_INSTALL_DIR}/${EXTRACTED_DIR}"

FINAL_NAME="$EXTRACTED_DIR"

if [[ -n "$PREDICTED_NAME" ]] && [[ "$EXTRACTED_DIR" != "$PREDICTED_NAME" ]]; then
	echo "Tarball's directory name (${EXTRACTED_DIR}) differs from the expected name (${PREDICTED_NAME}) for version ${SCALE_VERSION} -- renaming to match."
	rm -rf "${PREDICTED_NAME:?}"
	mv "$EXTRACTED_DIR" "$PREDICTED_NAME"
	FINAL_NAME="$PREDICTED_NAME"
fi

RESOLVED_ROOT="${SCALE_INSTALL_DIR}/${FINAL_NAME}"

if [[ ! -x "${RESOLVED_ROOT}/bin/scaleenv" ]]; then
	echo "error: ${RESOLVED_ROOT}/bin/scaleenv not found after install -- tarball layout may not match what setup-backends.sh expects" >&2
	exit 1
fi

echo "SCALE ${SCALE_VERSION} installed and verified at ${RESOLVED_ROOT}"
echo "$RESOLVED_ROOT" > "$MARKER_FILE"
