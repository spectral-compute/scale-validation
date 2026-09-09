#!/usr/bin/env bash
#
# compare-scale-versions.sh
#
# Lives in scale-validation/ExtendedOpenDwarfs/regression/, one level
# below scale-validation/ExtendedOpenDwarfs/ -- see ensure-scale.sh's own
# header for why (keeps this out of test.sh's non-recursive */*.sh glob).
#
# Runs the full regression fleet once for each of two SCALE versions,
# then diffs SCALE's own runtime between them (see
# plot-scale-version-diff.R) -- separate from, and in addition to, the
# usual SCALE-vs-native comparison that each individual run already
# produces via run-regression-fleet.sh.
#
# Usage:
#   ./compare-scale-versions.sh <version_a> <version_b> [extra env vars passed through as NAME=value ...]
#   ./compare-scale-versions.sh --replot <version_a> <version_b>
#
# Example:
#   ./compare-scale-versions.sh 1.7.1 1.7.2
#   ./compare-scale-versions.sh 1.7.1 1.7.2 EOD_REGRESSION_SIZE=tiny EOD_REGRESSION_ITERS=1
#   ./compare-scale-versions.sh --replot 1.7.1 1.7.2
#
# Anything after the two version arguments is passed through as
# additional environment variables for both fleet runs (size, iters,
# which hosts, etc. -- see run-regression-fleet.sh's own env var docs).
#
# --replot: if you already have two completed regression-runs/ directories
# from separate invocations (e.g. each version run separately, or via
# run-regression-fleet.sh's own EOD_REGRESSION_SKIP_RUN=1 re-collection)
# and don't want to re-run the fleet for either side, this resolves both
# directories the same way the normal flow does (newest
# */-scale<version> match under regression-runs/) and calls
# plot-scale-version-diff.R directly against them -- codifying what used
# to be "skip this wrapper and call the R script yourself" tribal
# knowledge in this header comment. No env vars are read/passed through
# in this mode (nothing is being run), and VERSION_A is still baseline /
# VERSION_B still candidate, same as the normal flow.
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_run_dir() {
	local version="$1"
	# regression-runs/ lives at scale-validation's root, which is two
	# levels above this script now (regression/ -> ExtendedOpenDwarfs/ ->
	# scale-validation/), not one.
	ls -td "${SCRIPT_DIR}/../../regression-runs/"*"-scale${version}" 2>/dev/null | head -1
}

# The EOD checkout that has pixi.toml / R (and plot-scale-version-diff.R
# runs against) is a SEPARATE, standalone clone of ExtendedOpenDwarfs
# living as a sibling of scale-validation itself -- NOT the ephemeral
# nested checkout 00-clone.sh recreates inside
# scale-validation/ExtendedOpenDwarfs/ExtendedOpenDwarfs/ for fleet hosts.
# This script lives three levels below that standalone clone's parent
# (regression/ -> ExtendedOpenDwarfs/ -> scale-validation/ -> parent dir),
# so three dirnames, not two.
EOD_REPO_ROOT="$(dirname "$(dirname "$(dirname "${SCRIPT_DIR}")")")/ExtendedOpenDwarfs"

run_diff_plot() {
	local dir_a="$1" dir_b="$2"
	if command -v pixi >/dev/null 2>&1 && [[ -f "${EOD_REPO_ROOT}/pixi.toml" ]]; then
		(cd "$EOD_REPO_ROOT" && pixi run Rscript "${SCRIPT_DIR}/plot-scale-version-diff.R" "$dir_a" "$dir_b")
	else
		echo "error: pixi not found (or no pixi.toml at ${EOD_REPO_ROOT}) -- cannot run R for the diff plot." >&2
		echo "       Run manually once R is available: Rscript ${SCRIPT_DIR}/plot-scale-version-diff.R '$dir_a' '$dir_b'" >&2
		exit 1
	fi
}

if [[ "${1:-}" == "--replot" ]]; then
	shift
	if [[ $# -lt 2 ]]; then
		echo "Usage: $0 --replot <baseline_version> <candidate_version>" >&2
		exit 1
	fi
	REPLOT_VERSION_A="$1"
	REPLOT_VERSION_B="$2"
	REPLOT_DIR_A="$(find_run_dir "$REPLOT_VERSION_A")"
	REPLOT_DIR_B="$(find_run_dir "$REPLOT_VERSION_B")"
	if [[ -z "$REPLOT_DIR_A" ]]; then
		echo "error: no regression-runs/ directory found for version ${REPLOT_VERSION_A} (looked for */-scale${REPLOT_VERSION_A})" >&2
		exit 1
	fi
	if [[ -z "$REPLOT_DIR_B" ]]; then
		echo "error: no regression-runs/ directory found for version ${REPLOT_VERSION_B} (looked for */-scale${REPLOT_VERSION_B})" >&2
		exit 1
	fi
	echo "Baseline (${REPLOT_VERSION_A}):  ${REPLOT_DIR_A}" >&2
	echo "Candidate (${REPLOT_VERSION_B}): ${REPLOT_DIR_B}" >&2
	run_diff_plot "$REPLOT_DIR_A" "$REPLOT_DIR_B"
	exit 0
fi

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
# A version-diff only ever compares SCALE's own runtime between the two
# versions under test (see plot-scale-version-diff.R, which explicitly
# excludes native toolchains) -- native (nvcc/hipcc) builds are out of
# scope for both fleet runs this script makes, not just extra work.
# Forced on by default (rather than a flat, unconditional export) so an
# explicit NAME=value pair above can still override it back to 0 if a
# caller genuinely wants native results out of a version-diff run too.
: "${EOD_REGRESSION_SCALE_ONLY:=1}"
export EOD_REGRESSION_SCALE_ONLY
run_fleet() {
	local version="$1"
	local role="$2"   # "baseline" (version_a) or "candidate" (version_b)
	echo "=== Running fleet for SCALE ${version} (${role}) ===" >&2
	# Deliberately NOT wrapped in $(...) here -- run-regression-fleet.sh's
	# own progress output (repo/ref banner, per-host start/complete
	# lines) needs to reach the terminal live, the same way it does when
	# invoked directly. Capturing this whole call in a command
	# substitution (as an earlier version of this script did) silently
	# swallows every line of that output into a variable instead of
	# printing it -- the run isn't frozen in that case, it just looks
	# that way because nothing is visible until the whole thing finishes.
	if [[ "$role" == "baseline" && -n "${EOD_REGRESSION_LOCAL_SCALE_BUILD:-}" ]]; then
		# EOD_REGRESSION_LOCAL_SCALE_BUILD, if the caller set it, only ever
		# applies to the candidate (version_b) side -- e.g. "does this
		# prospective release regress against the last published version"
		# needs the baseline to always be a real, reproducible published
		# release fetched via ensure-scale.sh, never whatever local build
		# happens to be sitting around for the OTHER side of the
		# comparison. Unset it just for this call, so setting it once,
		# globally, for the candidate can't silently also point the
		# baseline at that same local build.
		env -u EOD_REGRESSION_LOCAL_SCALE_BUILD \
			EOD_REGRESSION_SCALE_VERSION="$version" "${SCRIPT_DIR}/run-regression-fleet.sh"
	else
		EOD_REGRESSION_SCALE_VERSION="$version" "${SCRIPT_DIR}/run-regression-fleet.sh"
	fi
}
# find_run_dir, EOD_REPO_ROOT, and run_diff_plot are all defined up top
# (shared with the --replot path above) -- not redefined here.
run_fleet "$VERSION_A" baseline
DIR_A="$(find_run_dir "$VERSION_A")"
if [[ -z "$DIR_A" ]]; then
	echo "error: could not locate the regression-runs/ directory just produced for version ${VERSION_A}" >&2
	exit 1
fi
echo "Version ${VERSION_A} run: ${DIR_A}" >&2
run_fleet "$VERSION_B" candidate
DIR_B="$(find_run_dir "$VERSION_B")"
if [[ -z "$DIR_B" ]]; then
	echo "error: could not locate the regression-runs/ directory just produced for version ${VERSION_B}" >&2
	exit 1
fi
echo "Version ${VERSION_B} run: ${DIR_B}" >&2
run_diff_plot "$DIR_A" "$DIR_B"
