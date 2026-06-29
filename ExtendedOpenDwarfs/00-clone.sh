#!/bin/bash
set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

repo="${EXTENDED_OPEN_DWARFS_REPO:-https://github.com/ANU-HPC/ExtendedOpenDwarfs.git}"
ref="${EXTENDED_OPEN_DWARFS_REF:-$(get_version ExtendedOpenDwarfs)}"

if [[ -n "${EXTENDED_OPEN_DWARFS_LOCAL:-}" ]]; then
	cp -a "${EXTENDED_OPEN_DWARFS_LOCAL}" ExtendedOpenDwarfs
else
	if git ls-remote --heads --tags "$repo" "$ref" | grep -q .; then
		do_clone ExtendedOpenDwarfs "$repo" "$ref"
	else
		do_clone_hash ExtendedOpenDwarfs "$repo" "$ref"
	fi
fi

# Preserve the SCALE install root for later EOD stages without modifying test.sh.
if [[ -x "${2:-}/bin/scaleenv" ]]; then
	realpath "$2" > .scale-root
fi
