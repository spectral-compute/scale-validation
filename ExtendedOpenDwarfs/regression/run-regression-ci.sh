#!/usr/bin/env bash
#
# run-regression-ci.sh
#
# Lives in scale-validation/ExtendedOpenDwarfs/regression/, alongside
# ensure-scale.sh, run-regression-fleet.sh, compare-scale-versions.sh, and
# plot-scale-version-diff.R.
#
# CI-facing entry point for the SCALE version-regression tooling in this
# directory. Wraps run-regression-fleet.sh (single-version, vs-native) and
# compare-scale-versions.sh (two-version, vs-baseline) behind one command
# with a stable, predictable output location -- so a CI job only needs to
# know this one script's interface, not the internals of how the fleet is
# orchestrated or where regression-runs/<timestamp>-scale<version>/ or
# regression-runs/version-diff-<a>-vs-<b>/ end up.
#
# This does NOT touch, modify, or rename anything run-regression-fleet.sh,
# plot_heatmap.R, or plot-scale-version-diff.R already produce -- and it
# never touches the paper's own default SCALE-vs-native evaluation
# pipeline at all. It only locates and COPIES their already-generated
# output into a fixed CI-facing directory alongside a short summary, so a
# CI artifact-upload step doesn't need to discover a timestamped path.
#
# Usage:
#   ./run-regression-ci.sh <mode> <version> [baseline] [NAME=value ...]
#
#   mode      One of:
#               native        Run the fleet once, for <version> only.
#                              Deliverable: <version>'s own SCALE-vs-native
#                              heatmap/CSV (scale_vs_native_heatmap_*,
#                              scale_vs_native_ratio_*).
#               version-diff  Run the fleet for both <baseline> and
#                              <version> via compare-scale-versions.sh.
#                              Deliverable: the <baseline>-vs-<version>
#                              regression heatmap/CSV
#                              (scale_version_diff_heatmap_*,
#                              scale_version_diff_*).
#               both          Everything version-diff produces, PLUS
#                              <version>'s own vs-native heatmap surfaced
#                              alongside it. No extra fleet run is needed
#                              for this -- compare-scale-versions.sh's two
#                              underlying runs already each generate their
#                              own vs-native heatmap as a side effect; this
#                              mode just also collates <version>'s copy.
#   version   The SCALE version under test (the "candidate"), e.g. 1.7.2.
#   baseline  A prior SCALE version to diff against, e.g. 1.7.1.
#             Required for mode=version-diff or mode=both. Omit for
#             mode=native.
#
# Anything after <mode>/<version>/[baseline] is passed through as
# environment variables to the underlying fleet run(s) -- EOD_REGRESSION_
# ITERS, EOD_REGRESSION_APP, EOD_REGRESSION_SIZE, EOD_REGRESSION_REMOTE_
# TARGETS, etc. -- exactly like compare-scale-versions.sh's own
# passthrough (which this script defers to for version-diff/both).
#
# Examples:
#   # Nightly: does 1.7.2 still look reasonable against native toolchains?
#   ./run-regression-ci.sh native 1.7.2
#
#   # After cutting a new release: did anything regress since the last one?
#   ./run-regression-ci.sh both 1.7.2 1.7.1
#
#   # Fast smoke-test version of the same question:
#   ./run-regression-ci.sh version-diff 1.7.2 1.7.1 EOD_REGRESSION_SIZE=tiny EOD_REGRESSION_ITERS=1
#
# Output:
#   Writes a stable (overwritten each run, NOT timestamped) directory at
#   regression-runs/ci-latest/ off scale-validation's root, containing:
#     native/         Copy of <version>'s scale_vs_native_heatmap_*.pdf and
#                      scale_vs_native_ratio_*.csv (mode=native or both).
#     version-diff/   Copy of the <baseline>-vs-<version> diff heatmap/CSV
#                      (mode=version-diff or both).
#     SUMMARY.md      What was compared, when, and where the full
#                      (timestamped) underlying regression-runs/
#                      directories live, for anyone who wants to dig past
#                      the summary.
#   This directory's name is deliberately distinct from both the paper's
#   own default heatmap outputs and the raw timestamped
#   regression-runs/<timestamp>-scale<version>/ dirs, so it can never be
#   confused with either -- it is purely a "here is what a CI artifact
#   step should upload" convenience copy.
#
#   Exit code reflects whether the underlying run(s) succeeded and
#   produced the expected files. It is NOT a pass/fail judgement on the
#   regression itself -- no ratio threshold is applied here, and none of
#   the numbers are inspected. Reading the heatmap/summary to decide
#   whether a change is acceptable is still a human step.
#
#   NOTE: checksum/correctness comparison across SCALE versions is not
#   part of this yet -- that depends on lsb_common.R being extended to
#   extract each benchmark's recorded checksum (tracked separately). Once
#   that lands, this script is the natural place to also surface a
#   checksum-mismatch flag alongside the timing diff.
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCALE_VALIDATION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
	cat <<-END >&2
	Usage: $0 <mode> <version> [baseline] [NAME=value ...]

	  mode      one of: native, version-diff, both
	  version   the SCALE version under test (the "candidate"), e.g. 1.7.2
	  baseline  a prior SCALE version to diff against, e.g. 1.7.1 --
	            required for mode=version-diff or mode=both, omitted for mode=native

	Examples:
	  $0 native 1.7.2
	  $0 both 1.7.2 1.7.1
	  $0 version-diff 1.7.2 1.7.1 EOD_REGRESSION_SIZE=tiny EOD_REGRESSION_ITERS=1
	END
}

if [[ $# -lt 2 ]]; then
	usage
	exit 1
fi

MODE="$1"
VERSION="$2"
shift 2

case "$MODE" in
	native|version-diff|both) ;;
	*)
		echo "error: mode must be one of: native, version-diff, both (got '$MODE')" >&2
		usage
		exit 1
		;;
esac

BASELINE=""
if [[ "$MODE" != "native" ]]; then
	if [[ $# -lt 1 || "$1" == *=* ]]; then
		echo "error: mode=$MODE requires a <baseline> version argument (a prior SCALE version to diff against)" >&2
		usage
		exit 1
	fi
	BASELINE="$1"
	shift
fi

# Remaining args are NAME=value pairs, passed straight through to the
# underlying fleet run(s) -- same convention as compare-scale-versions.sh.
for kv in "$@"; do
	export "${kv?}"
done

find_run_dir() {
	local version="$1"
	ls -td "${SCALE_VALIDATION_ROOT}/regression-runs/"*"-scale${version}" 2>/dev/null | head -1
}

CI_OUT_DIR="${SCALE_VALIDATION_ROOT}/regression-runs/ci-latest"
rm -rf "$CI_OUT_DIR"
mkdir -p "$CI_OUT_DIR"
SUMMARY="${CI_OUT_DIR}/SUMMARY.md"
{
	echo "# SCALE regression CI run"
	echo
	echo "- Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "- Mode: ${MODE}"
	echo "- Candidate SCALE version: ${VERSION}"
	[[ -n "$BASELINE" ]] && echo "- Baseline SCALE version: ${BASELINE}"
} > "$SUMMARY"

RUN_DIR_VERSION=""
RUN_DIR_BASELINE=""

if [[ "$MODE" == "native" ]]; then
	echo "=== run-regression-ci.sh: running fleet for SCALE ${VERSION} (native comparison only) ===" >&2
	EOD_REGRESSION_SCALE_VERSION="$VERSION" "${SCRIPT_DIR}/run-regression-fleet.sh"
	RUN_DIR_VERSION="$(find_run_dir "$VERSION")"
	if [[ -z "$RUN_DIR_VERSION" ]]; then
		echo "error: could not locate the regression-runs/ directory just produced for version ${VERSION}" >&2
		exit 1
	fi
else
	echo "=== run-regression-ci.sh: running compare-scale-versions.sh for ${BASELINE} vs ${VERSION} ===" >&2
	"${SCRIPT_DIR}/compare-scale-versions.sh" "$BASELINE" "$VERSION"
	RUN_DIR_BASELINE="$(find_run_dir "$BASELINE")"
	RUN_DIR_VERSION="$(find_run_dir "$VERSION")"
	if [[ -z "$RUN_DIR_BASELINE" || -z "$RUN_DIR_VERSION" ]]; then
		echo "error: could not locate both regression-runs/ directories after compare-scale-versions.sh (baseline=${RUN_DIR_BASELINE:-<missing>}, version=${RUN_DIR_VERSION:-<missing>})" >&2
		exit 1
	fi
fi

# ---------------------------------------------------------------------------
# Collation helpers. Both are read-only with respect to the source
# directories -- they only ever cp into $CI_OUT_DIR, never move/rename the
# originals, so the raw timestamped regression-runs/ output this script
# read from is untouched and still there for anyone who wants the full
# detail (or to hand to plot-scale-version-diff.R again directly).
# ---------------------------------------------------------------------------
copy_native_heatmap() {
	local run_dir="$1" dest="$2"
	mkdir -p "$dest"
	local found=0
	for metric_dir in "${run_dir}/plots"/*/; do
		[[ -d "$metric_dir" ]] || continue
		for f in "${metric_dir}"scale_vs_native_heatmap_*.pdf "${metric_dir}"scale_vs_native_ratio_*.csv; do
			[[ -e "$f" ]] || continue
			cp "$f" "$dest/"
			found=1
		done
	done
	if [[ "$found" == "0" ]]; then
		echo "WARNING: no scale_vs_native_* outputs found under ${run_dir}/plots -- did that run's heatmap step complete?" >&2
		return 1
	fi
}

copy_version_diff_heatmap() {
	local baseline="$1" version="$2" dest="$3"
	mkdir -p "$dest"
	local diff_dir
	diff_dir="$(ls -td "${SCALE_VALIDATION_ROOT}/regression-runs/version-diff-${baseline}-vs-${version}"* 2>/dev/null | head -1)"
	if [[ -z "$diff_dir" ]]; then
		echo "error: could not locate version-diff output directory for ${baseline} vs ${version} under regression-runs/" >&2
		return 1
	fi
	local found=0
	for metric_dir in "${diff_dir}"/*/; do
		[[ -d "$metric_dir" ]] || continue
		for f in "${metric_dir}"scale_version_diff_heatmap_*.pdf "${metric_dir}"scale_version_diff_*.csv; do
			[[ -e "$f" ]] || continue
			cp "$f" "$dest/"
			found=1
		done
	done
	if [[ "$found" == "0" ]]; then
		echo "WARNING: no scale_version_diff_* outputs found under ${diff_dir}" >&2
		return 1
	fi
	echo "$diff_dir"
}

OVERALL_OK=1

if [[ "$MODE" == "native" || "$MODE" == "both" ]]; then
	echo "--- collating native comparison for ${VERSION} ---" >&2
	if copy_native_heatmap "$RUN_DIR_VERSION" "${CI_OUT_DIR}/native"; then
		{
			echo
			echo "## Native comparison (SCALE ${VERSION} vs NVCC/HIPCC)"
			echo "- Full run: ${RUN_DIR_VERSION}"
			echo "- Artifacts: native/"
		} >> "$SUMMARY"
	else
		OVERALL_OK=0
	fi
fi

if [[ "$MODE" == "version-diff" || "$MODE" == "both" ]]; then
	echo "--- collating version diff for ${BASELINE} vs ${VERSION} ---" >&2
	if diff_dir="$(copy_version_diff_heatmap "$BASELINE" "$VERSION" "${CI_OUT_DIR}/version-diff")"; then
		{
			echo
			echo "## Version regression (SCALE ${BASELINE} -> ${VERSION})"
			echo "- Baseline run: ${RUN_DIR_BASELINE}"
			echo "- Candidate run: ${RUN_DIR_VERSION}"
			echo "- Diff run: ${diff_dir}"
			echo "- Artifacts: version-diff/"
		} >> "$SUMMARY"
	else
		OVERALL_OK=0
	fi
fi

echo >&2
echo "=== run-regression-ci.sh complete ===" >&2
echo "Summary:   ${SUMMARY}" >&2
echo "Artifacts: ${CI_OUT_DIR}" >&2

if [[ "$OVERALL_OK" != "1" ]]; then
	echo "error: one or more expected output sets were missing -- see warnings above" >&2
	exit 1
fi
