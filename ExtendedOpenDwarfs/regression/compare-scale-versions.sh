#!/usr/bin/env bash
#
# compare-scale-versions.sh
#
# Runs the full regression fleet once for each of two SCALE versions,
# then diffs SCALE's own runtime between them (see
# plot-scale-version-diff.R) -- separate from, and in addition to, the
# usual SCALE-vs-native comparison that each individual run already
# produces via run-regression-fleet.sh.
#
# Usage:
#   ./compare-scale-versions.sh <version_a> <version_b> [extra env vars passed through as NAME=value ...]
#
# Example:
#   ./compare-scale-versions.sh 1.7.1 1.7.2
#   ./compare-scale-versions.sh 1.7.1 1.7.2 EOD_REGRESSION_SIZE=tiny EOD_REGRESSION_ITERS=1
#
# Anything after the two version arguments is passed through as
# additional environment variables for both fleet runs (size, iters,
# which hosts, etc. -- see run-regression-fleet.sh's own env var docs).
#
# If you already have two completed regression-runs/ directories from
# separate invocations and don't want to re-run the fleet, skip this
# wrapper and call plot-scale-version-diff.R directly against them
# instead.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 2 ]]; then
	echo "Usage: $0 <version_a> <version_b> [NAME=value ...]" >&2
	exit 1
fi

VERSION_A="$1"
VERSION_B="$2"
shift 2

# Remaining args are NAME=value pairs to export for both fleet runs.
for kv in "$@"; do
	export "${kv?}"
done

run_fleet() {
	local version="$1"
	echo "=== Running fleet for SCALE ${version} ===" >&2
	# Deliberately NOT wrapped in $(...) here -- run-regression-fleet.sh's
	# own progress output (repo/ref banner, per-host start/complete
	# lines) needs to reach the terminal live, the same way it does when
	# invoked directly. Capturing this whole call in a command
	# substitution (as an earlier version of this script did) silently
	# swallows every line of that output into a variable instead of
	# printing it -- the run isn't frozen in that case, it just looks
	# that way because nothing is visible until the whole thing finishes.
	EOD_REGRESSION_SCALE_VERSION="$version" "${SCRIPT_DIR}/run-regression-fleet.sh"
}

find_run_dir() {
	local version="$1"
	# A separate, later command substitution -- only this one small `ls`
	# call's output gets captured, not the fleet run's output.
	ls -td "${SCRIPT_DIR}/../regression-runs/"*"-scale${version}" 2>/dev/null | head -1
}

run_fleet "$VERSION_A"
DIR_A="$(find_run_dir "$VERSION_A")"
if [[ -z "$DIR_A" ]]; then
	echo "error: could not locate the regression-runs/ directory just produced for version ${VERSION_A}" >&2
	exit 1
fi
echo "Version ${VERSION_A} run: ${DIR_A}" >&2

run_fleet "$VERSION_B"
DIR_B="$(find_run_dir "$VERSION_B")"
if [[ -z "$DIR_B" ]]; then
	echo "error: could not locate the regression-runs/ directory just produced for version ${VERSION_B}" >&2
	exit 1
fi
echo "Version ${VERSION_B} run: ${DIR_B}" >&2

EOD_REPO_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")/ExtendedOpenDwarfs"

if command -v pixi >/dev/null 2>&1 && [[ -f "${EOD_REPO_ROOT}/pixi.toml" ]]; then
	(cd "$EOD_REPO_ROOT" && pixi run Rscript "${SCRIPT_DIR}/plot-scale-version-diff.R" "$DIR_A" "$DIR_B")
else
	echo "error: pixi not found (or no pixi.toml at ${EOD_REPO_ROOT}) -- cannot run R for the diff plot." >&2
	echo "       Run manually once R is available: Rscript ${SCRIPT_DIR}/plot-scale-version-diff.R '$DIR_A' '$DIR_B'" >&2
	exit 1
fi
