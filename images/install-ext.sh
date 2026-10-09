#!/usr/bin/env bash
# Install a package from outside the distro package manager, for an `ext` entry in a
# `.dependencies` file. Takes the entry's `<name>=<version>` spec as its only argument.
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <name>=<version>" >&2
    exit 1
fi

SPEC="$1"
case "${SPEC}" in
*)
    echo "Unrecognised ext spec: ${SPEC}" >&2
    exit 1
    ;;
esac
