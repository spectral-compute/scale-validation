#!/usr/bin/env bash
#
# compare-scale-versions.sh
#
# Lives in scale-validation/ExtendedOpenDwarfs/regression/, one level
# below scale-validation/ExtendedOpenDwarfs/ -- see ensure-scale.sh's own
# header for why (keeps this out of test.sh's non-recursive */*.sh glob).
#
# Runs the full regression fleet once for each of two SCALE versions,
# then diffs SCALE's own runtime between them three ways -- separate
# from, and in addition to, the usual SCALE-vs-native comparison that
# each individual run already produces via run-regression-fleet.sh:
#   1. Whole-benchmark heatmap/CSV (plot-scale-version-diff.R): one ratio
#      per (benchmark, size, device).
#   2. Per-region heatmap/CSV (plot-scale-version-diff-by-region.R): one
#      ratio per (benchmark, size, device, region) -- so a regression
#      confined to one region isn't hidden by an offsetting change in
#      another within the same benchmark's whole-benchmark total.
#   3. Archived full box-and-whisker plot set for BOTH builds
#      (plot_lsb.R, run once per side) -- absolute distributions, not
#      ratios, for a point-wise comparison beyond what any ratio number
#      can show.
# All three land under one shared output directory per comparison --
# see "Output" below.
#
# Usage:
#   ./compare-scale-versions.sh <version_a> <version_b> \
#       [--baseline-label=<text>] [--candidate-label=<text>] \
#       [extra env vars passed through as NAME=value ...]
#   ./compare-scale-versions.sh --replot <version_a> <version_b> \
#       [--baseline-label=<text>] [--candidate-label=<text>]
#   ./compare-scale-versions.sh --archive <version_a> <version_b> [--out=<path.tar.gz>]
#
# Example:
#   ./compare-scale-versions.sh 1.7.1 1.7.2
#   ./compare-scale-versions.sh 1.7.1 1.7.2 EOD_REGRESSION_SIZE=tiny EOD_REGRESSION_ITERS=1
#   ./compare-scale-versions.sh --replot 1.7.2 1.7.3-rc --candidate-label=nightly-b4a9776f9817
#   ./compare-scale-versions.sh --archive 1.7.2 1.7.3-rc
#
# --archive: bundles what a normal run or --replot already produced into
# one tarball for handoff (e.g. to compiler devs doing a point-wise
# comparison) -- does not run or re-plot anything itself. Requires both
# sides' plots-full/ to already exist (any normal or --replot call
# archives these automatically). Written to
# regression-runs/comparison-archives/<a>-vs-<b>-<timestamp>.tar.gz by
# default, or to --out=<path> if given. Contents: baseline/ and
# candidate/ (each side's full plot_lsb.R box-and-whisker set, for a
# side-by-side comparison of the two builds' own region breakdowns), plus
# diff/ (the most recent whole-benchmark + per-region ratio
# heatmaps/CSVs for this exact pair, if one has been generated).
#
# Anything after the two version arguments is passed through as
# additional environment variables for both fleet runs (size, iters,
# which hosts, etc. -- see run-regression-fleet.sh's own env var docs),
# except the two --*-label flags below, which are handled here instead.
#
# --baseline-label / --candidate-label: text shown in title/filenames
# across all three outputs above instead of the version string parsed
# from each directory's own "-scale<version>" suffix -- for labelling a
# run with something more specific (e.g. an exact nightly build
# identifier) without needing that string to itself be a valid
# directory-naming version token. VERSION_A/VERSION_B (or their --replot
# equivalents) still drive directory lookup either way -- only display
# text changes.
#
# --replot: if you already have two completed regression-runs/ directories
# from separate invocations (e.g. each version run separately, or via
# run-regression-fleet.sh's own EOD_REGRESSION_SKIP_RUN=1 re-collection)
# and don't want to re-run the fleet for either side, this resolves both
# directories the same way the normal flow does (newest
# */-scale<version> match under regression-runs/) and runs all three
# outputs above directly against them -- codifying what used to be "skip
# this wrapper and call the R script yourself" tribal knowledge in this
# header comment. No env vars are read/passed through in this mode
# (nothing is being run), and VERSION_A is still baseline / VERSION_B
# still candidate, same as the normal flow.
#
# Output: everything lands under one directory,
#   regression-runs/version-diff-<a>-vs-<b>-<UTC timestamp>/
# containing:
#   <metric>/scale_version_diff_heatmap_*.pdf / *_ratio_*.csv   (whole-benchmark, see plot-scale-version-diff.R)
#   by-region/<arch>/<benchmark>_region_diff.pdf, by-region/*_ratio_*.csv (per-region)
# plus, alongside each raw run directory itself (not under the folder
# above, since these are per-build absolutes reusable across multiple
# diffs, not specific to this one comparison):
#   <run_dir>/plots-full/   full plot_lsb.R box-and-whisker set
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

make_out_root() {
	local version_a="$1" version_b="$2"
	local timestamp
	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	echo "${SCRIPT_DIR}/../../regression-runs/version-diff-${version_a}-vs-${version_b}-${timestamp}"
}

# The EOD checkout that has pixi.toml / R (and plot-scale-version-diff.R,
# plot-scale-version-diff-by-region.R, and plot_lsb.R all run against) is
# a SEPARATE, standalone clone of ExtendedOpenDwarfs living as a sibling
# of scale-validation itself -- NOT the ephemeral nested checkout
# 00-clone.sh recreates inside
# scale-validation/ExtendedOpenDwarfs/ExtendedOpenDwarfs/ for fleet hosts.
# This script lives three levels below that standalone clone's parent
# (regression/ -> ExtendedOpenDwarfs/ -> scale-validation/ -> parent dir),
# so three dirnames, not two.
EOD_REPO_ROOT="$(dirname "$(dirname "$(dirname "${SCRIPT_DIR}")")")/ExtendedOpenDwarfs"

run_diff_plot() {
	local dir_a="$1" dir_b="$2" out_root="$3"
	shift 3
	if command -v pixi >/dev/null 2>&1 && [[ -f "${EOD_REPO_ROOT}/pixi.toml" ]]; then
		(cd "$EOD_REPO_ROOT" && pixi run Rscript "${SCRIPT_DIR}/plot-scale-version-diff.R" "$dir_a" "$dir_b" "--out-dir=${out_root}" "$@")
	else
		echo "error: pixi not found (or no pixi.toml at ${EOD_REPO_ROOT}) -- cannot run R for the diff plot." >&2
		echo "       Run manually once R is available: Rscript ${SCRIPT_DIR}/plot-scale-version-diff.R '$dir_a' '$dir_b'" >&2
		exit 1
	fi
}

run_region_diff_plot() {
	local dir_a="$1" dir_b="$2" out_root="$3"
	shift 3
	if command -v pixi >/dev/null 2>&1 && [[ -f "${EOD_REPO_ROOT}/pixi.toml" ]]; then
		(cd "$EOD_REPO_ROOT" && pixi run Rscript "${SCRIPT_DIR}/plot-scale-version-diff-by-region.R" "$dir_a" "$dir_b" "--out-dir=${out_root}" "$@")
	else
		echo "error: pixi not found (or no pixi.toml at ${EOD_REPO_ROOT}) -- cannot run R for the region-diff plot." >&2
		echo "       Run manually once R is available: Rscript ${SCRIPT_DIR}/plot-scale-version-diff-by-region.R '$dir_a' '$dir_b'" >&2
		return 1
	fi
}

# Archives plot_lsb.R's full box-and-whisker plot set for ONE build's own
# raw results, into that build's own run directory (not the version-diff
# output directory above) -- these are per-build absolutes, meaningful on
# their own and reusable across multiple future diffs against this same
# build, not specific to any one comparison. Best-effort: a failure here
# (e.g. a plot_lsb.R bug on some new region shape) is logged as a warning
# by the caller, not fatal to the rest of a comparison.
archive_full_plots() {
	local run_dir="$1" role_label="$2"
	local results_dir="${run_dir}/results"
	local dest="${run_dir}/plots-full"
	if [[ ! -d "$results_dir" ]]; then
		echo "WARNING: no results/ under ${run_dir} -- skipping full plot archive for ${role_label}" >&2
		return 1
	fi
	echo "Archiving full box-and-whisker plot set for ${role_label} (${run_dir}) -> ${dest}" >&2
	if command -v pixi >/dev/null 2>&1 && [[ -f "${EOD_REPO_ROOT}/pixi.toml" ]]; then
		(cd "$EOD_REPO_ROOT" && pixi run Rscript "${EOD_REPO_ROOT}/scripts/plot_lsb.R" "$results_dir" "$dest")
	else
		echo "error: pixi not found (or no pixi.toml at ${EOD_REPO_ROOT}) -- cannot run R for the full plot archive." >&2
		echo "       Run manually once R is available: Rscript ${EOD_REPO_ROOT}/scripts/plot_lsb.R '$results_dir' '$dest'" >&2
		return 1
	fi
}

if [[ "${1:-}" == "--replot" ]]; then
	shift
	if [[ $# -lt 2 ]]; then
		echo "Usage: $0 --replot <baseline_version> <candidate_version> [--baseline-label=..] [--candidate-label=..]" >&2
		exit 1
	fi
	REPLOT_VERSION_A="$1"
	REPLOT_VERSION_B="$2"
	shift 2
	BASELINE_LABEL=""
	CANDIDATE_LABEL=""
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--baseline-label=*) BASELINE_LABEL="${1#--baseline-label=}" ;;
			--candidate-label=*) CANDIDATE_LABEL="${1#--candidate-label=}" ;;
			*) echo "warning: ignoring unrecognised --replot argument: $1" >&2 ;;
		esac
		shift
	done
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
	LABEL_ARGS=()
	[[ -n "$BASELINE_LABEL" ]] && LABEL_ARGS+=("--baseline-label=${BASELINE_LABEL}")
	[[ -n "$CANDIDATE_LABEL" ]] && LABEL_ARGS+=("--candidate-label=${CANDIDATE_LABEL}")
	OUT_ROOT="$(make_out_root "$REPLOT_VERSION_A" "$REPLOT_VERSION_B")"
	mkdir -p "$OUT_ROOT"
	echo "Output directory: ${OUT_ROOT}" >&2
	run_diff_plot "$REPLOT_DIR_A" "$REPLOT_DIR_B" "$OUT_ROOT" "${LABEL_ARGS[@]}"
	if ! run_region_diff_plot "$REPLOT_DIR_A" "$REPLOT_DIR_B" "$OUT_ROOT" "${LABEL_ARGS[@]}"; then
		echo "WARNING: per-region diff failed -- see output above; whole-benchmark diff above is unaffected" >&2
	fi
	archive_full_plots "$REPLOT_DIR_A" "baseline (${REPLOT_VERSION_A})" || echo "WARNING: full plot archive failed for baseline -- see output above" >&2
	archive_full_plots "$REPLOT_DIR_B" "candidate (${REPLOT_VERSION_B})" || echo "WARNING: full plot archive failed for candidate -- see output above" >&2
	exit 0
fi

if [[ "${1:-}" == "--archive" ]]; then
	shift
	if [[ $# -lt 2 ]]; then
		echo "Usage: $0 --archive <baseline_version> <candidate_version> [--out=<path.tar.gz>]" >&2
		exit 1
	fi
	ARCHIVE_VERSION_A="$1"
	ARCHIVE_VERSION_B="$2"
	shift 2
	ARCHIVE_OUT=""
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--out=*) ARCHIVE_OUT="${1#--out=}" ;;
			*) echo "warning: ignoring unrecognised --archive argument: $1" >&2 ;;
		esac
		shift
	done
	ARCHIVE_DIR_A="$(find_run_dir "$ARCHIVE_VERSION_A")"
	ARCHIVE_DIR_B="$(find_run_dir "$ARCHIVE_VERSION_B")"
	if [[ -z "$ARCHIVE_DIR_A" ]]; then
		echo "error: no regression-runs/ directory found for version ${ARCHIVE_VERSION_A} (looked for */-scale${ARCHIVE_VERSION_A})" >&2
		exit 1
	fi
	if [[ -z "$ARCHIVE_DIR_B" ]]; then
		echo "error: no regression-runs/ directory found for version ${ARCHIVE_VERSION_B} (looked for */-scale${ARCHIVE_VERSION_B})" >&2
		exit 1
	fi
	if [[ ! -d "${ARCHIVE_DIR_A}/plots-full" ]]; then
		echo "error: no plots-full/ under ${ARCHIVE_DIR_A} -- a normal or --replot compare-scale-versions.sh call archives this automatically; run one of those first" >&2
		exit 1
	fi
	if [[ ! -d "${ARCHIVE_DIR_B}/plots-full" ]]; then
		echo "error: no plots-full/ under ${ARCHIVE_DIR_B} -- a normal or --replot compare-scale-versions.sh call archives this automatically; run one of those first" >&2
		exit 1
	fi
	# Most recent whole-benchmark + per-region diff output for this exact
	# pair, if one exists -- included alongside the raw plots-full/
	# archives so the handoff has both the ratio heatmaps AND the
	# absolute distributions in one place. Not required: archiving still
	# proceeds (with a warning) if no diff has been run yet.
	DIFF_DIR="$(ls -td "${SCRIPT_DIR}/../../regression-runs/version-diff-${ARCHIVE_VERSION_A}-vs-${ARCHIVE_VERSION_B}-"* 2>/dev/null | head -1)"
	if [[ -z "$DIFF_DIR" ]]; then
		echo "warning: no version-diff-${ARCHIVE_VERSION_A}-vs-${ARCHIVE_VERSION_B}-* directory found -- archive will contain plots-full/ only, no ratio heatmaps/CSVs" >&2
	fi
	if [[ -z "$ARCHIVE_OUT" ]]; then
		ARCHIVE_DEST_DIR="${SCRIPT_DIR}/../../regression-runs/comparison-archives"
		mkdir -p "$ARCHIVE_DEST_DIR"
		ARCHIVE_OUT="${ARCHIVE_DEST_DIR}/${ARCHIVE_VERSION_A}-vs-${ARCHIVE_VERSION_B}-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
	else
		mkdir -p "$(dirname "$ARCHIVE_OUT")"
	fi
	STAGE_DIR="$(mktemp -d)"
	trap 'rm -rf "$STAGE_DIR"' EXIT
	mkdir -p "${STAGE_DIR}/baseline" "${STAGE_DIR}/candidate"
	cp -r "${ARCHIVE_DIR_A}/plots-full/." "${STAGE_DIR}/baseline/"
	cp -r "${ARCHIVE_DIR_B}/plots-full/." "${STAGE_DIR}/candidate/"
	TAR_ENTRIES=(baseline candidate)
	if [[ -n "$DIFF_DIR" ]]; then
		mkdir -p "${STAGE_DIR}/diff"
		cp -r "${DIFF_DIR}/." "${STAGE_DIR}/diff/"
		TAR_ENTRIES+=(diff)
	fi
	tar czf "$ARCHIVE_OUT" -C "$STAGE_DIR" "${TAR_ENTRIES[@]}"
	echo "Wrote comparison archive: ${ARCHIVE_OUT}" >&2
	echo "  baseline/  -- SCALE ${ARCHIVE_VERSION_A}'s full box-and-whisker plot set (plot_lsb.R)" >&2
	echo "  candidate/ -- SCALE ${ARCHIVE_VERSION_B}'s full box-and-whisker plot set (plot_lsb.R)" >&2
	if [[ -n "$DIFF_DIR" ]]; then
		echo "  diff/      -- whole-benchmark + per-region ratio heatmaps/CSVs (${DIFF_DIR})" >&2
	fi
	exit 0
fi

if [[ $# -lt 2 ]]; then
	echo "Usage: $0 <version_a> <version_b> [--baseline-label=..] [--candidate-label=..] [NAME=value ...]" >&2
	exit 1
fi
VERSION_A="$1"
VERSION_B="$2"
shift 2
BASELINE_LABEL=""
CANDIDATE_LABEL=""
REMAINING_KV=()
for arg in "$@"; do
	case "$arg" in
		--baseline-label=*) BASELINE_LABEL="${arg#--baseline-label=}" ;;
		--candidate-label=*) CANDIDATE_LABEL="${arg#--candidate-label=}" ;;
		*) REMAINING_KV+=("$arg") ;;
	esac
done
# Remaining args are NAME=value pairs to export for both fleet runs.
for kv in "${REMAINING_KV[@]+"${REMAINING_KV[@]}"}"; do
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
# find_run_dir, make_out_root, EOD_REPO_ROOT, run_diff_plot,
# run_region_diff_plot, and archive_full_plots are all defined up top
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
LABEL_ARGS=()
[[ -n "$BASELINE_LABEL" ]] && LABEL_ARGS+=("--baseline-label=${BASELINE_LABEL}")
[[ -n "$CANDIDATE_LABEL" ]] && LABEL_ARGS+=("--candidate-label=${CANDIDATE_LABEL}")
OUT_ROOT="$(make_out_root "$VERSION_A" "$VERSION_B")"
mkdir -p "$OUT_ROOT"
echo "Output directory: ${OUT_ROOT}" >&2
run_diff_plot "$DIR_A" "$DIR_B" "$OUT_ROOT" "${LABEL_ARGS[@]+"${LABEL_ARGS[@]}"}"
if ! run_region_diff_plot "$DIR_A" "$DIR_B" "$OUT_ROOT" "${LABEL_ARGS[@]+"${LABEL_ARGS[@]}"}"; then
	echo "WARNING: per-region diff failed -- see output above; whole-benchmark diff above is unaffected" >&2
fi
archive_full_plots "$DIR_A" "baseline (${VERSION_A})" || echo "WARNING: full plot archive failed for baseline -- see output above" >&2
archive_full_plots "$DIR_B" "candidate (${VERSION_B})" || echo "WARNING: full plot archive failed for candidate -- see output above" >&2
