#!/usr/bin/env bash
set -ETeuo pipefail
SCALE_VALIDATION="$(dirname "$0")/../"

look_for_marker() {
    NO_FORMAT="\033[0m"
    F_INVERT="\033[7m"
    F_BOLD="\033[1m"
    echo -e "${F_INVERT}$1${NO_FORMAT}"
    while read -r F; do
        DIR="$(dirname "$F")"
        echo -e "  ${F_BOLD}${DIR##*/}${NO_FORMAT}"
        cat "$F" | sed 's/^/    /'
    done < <(find "$SCALE_VALIDATION" -name "$2")
    echo ""
}

echo ""
look_for_marker "Skipped in CI" ".skip-ci"
look_for_marker "No test scripts" ".build-only"
look_for_marker "Build will fail" ".build-fails*"
look_for_marker "Running tests will fail" ".run-fails*"
