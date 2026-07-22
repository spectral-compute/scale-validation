#!/usr/bin/env bash
#
# run_regression_fleet.sh
#
# Lives in scale-validation/ExtendedOpenDwarfs/, alongside 00-clone.sh,
# 01-install-deps.sh, ensure_scale.sh, etc. -- deliberately NOT inside the
# ExtendedOpenDwarfs project's own repo, since that's a public upstream
# (ANU-HPC) benchmark suite and this is Spectral-Compute-internal fleet
# orchestration tooling.
#
# Farms scripts/run_scale_eod_paper.sh (see NOTE below) out to every
# configured Spectral Compute host, waits for each host's sweep to finish
# (independently -- one host's failure or timeout does not block the
# others), rsyncs every host's results/ back to a single timestamped local
# directory, and runs plot_heatmap.R against the combined dataset to
# produce the SCALE-vs-native heatmap.
#
# Hosts are all Spectral Compute machines (trill, alpha, epsilon, beta,
# andoria, risa) -- ExCL is intentionally excluded. Each host has its own
# independent filesystem (no shared NFS between them), so there is no lock
# contention or shared-state risk running every host's sweep at the same
# time; this script launches all of them as background jobs in parallel
# rather than one at a time.
#
# What gets distributed to each host is scale-validation itself (this
# repo), not a bare ExtendedOpenDwarfs checkout. This matters for two
# reasons:
#   - scale-validation is the repo Spectral Compute actually controls and
#     already deploys to every host -- unlike the public EOD upstream, it
#     can carry this fleet-orchestration tooling and reach every host via
#     a normal git clone.
#   - scale-validation's own 00-clone.sh / versions.txt already pin an
#     exact EOD commit. Pinning and distributing scale-validation to an
#     exact ref therefore also pins the EOD commit under test, without
#     needing a second, separate "which EOD commit" concept to track.
#
# Every host -- including the one this script is invoked from -- works
# from its own self-contained clone under a scratch directory (default:
# /tmp/eod-regression), which this script manages itself (clone-if-
# missing, then fetch + hard-reset to a pinned commit). That means:
#   - No assumption that a checkout already exists at some specific path
#     on any host.
#   - No specific username baked in -- remote targets are plain hostnames
#     by default, and ssh resolves the username the normal way (matching
#     local username, or via a Host entry in ~/.ssh/config).
#   - Safe to always hard-reset that scratch clone, since it's scratch
#     space nobody does interactive work in -- unlike resetting someone's
#     real working checkout.
#
# By default this also ensures a specific SCALE version is installed on
# each host before sweeping (see ensure_scale.sh, alongside this script).
# Different SCALE versions install side by side under the same scratch
# checkout, so toggling EOD_REGRESSION_SCALE_VERSION between runs -- e.g.
# to compare 1.7.1 against 1.7.2 -- only pays a download cost the first
# time each version is used on a given host.
#
# NOTE on run_scale_eod_paper.sh: this script currently still shells out
# to run_scale_eod_paper.sh for the actual per-device sweep (it knows how
# to fan a single host out across multiple physical GPUs with the correct
# arch/backend/compiler pairing for each -- necessary on multi-GPU boxes
# like trill and alpha). That script has the same "Spectral-Compute-
# specific, shouldn't live in public upstream EOD" problem this one did --
# it's currently invoked as "cd ExtendedOpenDwarfs && ./runner.sh" from
# one directory level relative to where IT lives, which needs to match
# wherever it actually ends up. If/when you relocate it here too (next to
# this script, alongside the 00-03 numbered scripts), its internal calls
# into runner.sh will need a "cd ExtendedOpenDwarfs" prefix added, since
# from here the nested EOD checkout is one level down
# (scale-validation/ExtendedOpenDwarfs/ExtendedOpenDwarfs/), not the
# current directory. Happy to produce that as a precise TPP once you
# paste its current contents.
#
# NOTE on plot_heatmap.R: only ever runs locally, on whichever machine
# collects results -- it is never distributed to the fleet hosts. Keep it
# (and its lsb_common.R dependency) alongside this script.
#
# Usage:
#   ./run_regression_fleet.sh
#   EOD_REGRESSION_SCALE_VERSION=1.7.1 ./run_regression_fleet.sh
#   EOD_REGRESSION_SCALE_VERSION=1.7.2 ./run_regression_fleet.sh
#
# Configuration is via environment variables (all optional, sane defaults
# shown). This intentionally mirrors the style of setup-backends.sh /
# runner.sh rather than introducing a new flag-parsing convention:
#
#   EOD_REGRESSION_REMOTE_TARGETS
#       Space-separated list of ssh destinations to farm the sweep out to.
#       Plain hostnames by default -- no username is prepended, so ssh
#       resolves it the normal way (current user, or ~/.ssh/config).
#       Default: "alpha epsilon beta andoria risa"
#
#   EOD_REGRESSION_RUN_LOCAL
#       1 to also run the sweep on the machine invoking this script (e.g.
#       trill), 0 to only run on the remote targets. Default: 1
#
#   EOD_REGRESSION_WORKDIR
#       Scratch directory on each host (local and remote) to clone
#       scale-validation into and work from. Reused across runs (fetch +
#       reset rather than a fresh clone every time), so repeated runs are
#       fast. SCALE version(s) get installed inside the nested
#       ExtendedOpenDwarfs/ directory, per ensure_scale.sh's own default.
#       Default: "/tmp/eod-regression"
#
#   EOD_REGRESSION_REPO_URL
#       Git URL to clone scale-validation from on hosts that don't have it
#       yet. Default: auto-detected from this checkout's own "origin"
#       remote.
#
#   EOD_REGRESSION_REF
#       Exact commit, tag, or branch of scale-validation to pin every host
#       to (which in turn determines the EOD commit under test, via that
#       ref's own versions.txt / 00-clone.sh). Default: auto-detected as
#       the commit currently checked out in this checkout (i.e. "test
#       exactly this state, everywhere"). Override to a tag for release
#       testing.
#
#   EOD_REGRESSION_ENSURE_SCALE
#       1 (default) to run ensure_scale.sh on each host before the sweep,
#       installing the requested SCALE_VERSION if it's missing, and
#       exporting SCALE_ROOT to point at it. 0 to skip this entirely and
#       use whatever SCALE_ROOT (or setup-backends.sh's own default) is
#       already in effect on each host.
#
#   EOD_REGRESSION_SCALE_VERSION
#       Which SCALE version to ensure/use on every host, e.g. "1.7.1",
#       "1.7.2", or "latest". See https://pkgs.scale-lang.com/tar/ for the
#       full list of available versions. Default: "latest"
#       Only meaningful when EOD_REGRESSION_ENSURE_SCALE=1.
#
#   EOD_REGRESSION_TIMEOUT
#       Per-host wall-clock timeout in seconds, covering the clone/sync,
#       SCALE install check (if enabled), and the sweep itself.
#       Default: 1800 (30 minutes). A stuck host is killed and marked
#       FAILED rather than hanging the whole fleet run indefinitely.
#
#   EOD_REGRESSION_APP / EOD_REGRESSION_SIZE / EOD_REGRESSION_ITERS
#       Passed through as APP/SIZE/ITERS to run_scale_eod_paper.sh on
#       every host. Defaults match that script's own defaults (all/all/5).
#       Override to e.g. SIZE=tiny ITERS=1 for a fast smoke-test run
#       rather than a full release sweep.
#
#   EOD_REGRESSION_SKIP_RUN
#       1 to skip the clone/sync, SCALE-install-check, and build+run steps
#       entirely, and just re-collect + re-plot from whatever results/
#       directories already exist under EOD_REGRESSION_WORKDIR on each
#       host right now. Useful for iterating on the plotting step, or for
#       re-generating a heatmap after a partial failure without
#       re-running every host's multi-minute sweep. Default: 0
#
#   EOD_REGRESSION_METRIC
#       Passed through as --metric=<value> to plot_heatmap.R. Leave unset
#       to use plot_heatmap.R's own default (runs both "kernel" and
#       "total" in one invocation).
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCALE_VALIDATION_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

: "${EOD_REGRESSION_REMOTE_TARGETS:=alpha epsilon beta andoria risa}"
read -r -a REMOTE_TARGETS <<< "$EOD_REGRESSION_REMOTE_TARGETS"

: "${EOD_REGRESSION_RUN_LOCAL:=1}"
: "${EOD_REGRESSION_WORKDIR:=/tmp/eod-regression}"
: "${EOD_REGRESSION_ENSURE_SCALE:=1}"
: "${EOD_REGRESSION_SCALE_VERSION:=latest}"
: "${EOD_REGRESSION_TIMEOUT:=1800}"
: "${EOD_REGRESSION_APP:=all}"
: "${EOD_REGRESSION_SIZE:=all}"
: "${EOD_REGRESSION_ITERS:=5}"
: "${EOD_REGRESSION_SKIP_RUN:=0}"
: "${EOD_REGRESSION_METRIC:=}"

if [[ -z "${EOD_REGRESSION_REPO_URL:-}" ]]; then
	if ! EOD_REGRESSION_REPO_URL="$(git -C "$SCALE_VALIDATION_ROOT" remote get-url origin 2>/dev/null)"; then
		echo "error: could not auto-detect the git origin URL from ${SCALE_VALIDATION_ROOT}." >&2
		echo "       Set EOD_REGRESSION_REPO_URL explicitly and re-run." >&2
		exit 1
	fi
fi

if [[ -z "${EOD_REGRESSION_REF:-}" ]]; then
	if ! EOD_REGRESSION_REF="$(git -C "$SCALE_VALIDATION_ROOT" rev-parse HEAD 2>/dev/null)"; then
		echo "error: could not auto-detect the current commit from ${SCALE_VALIDATION_ROOT}." >&2
		echo "       Set EOD_REGRESSION_REF explicitly (a commit, tag, or branch) and re-run." >&2
		exit 1
	fi
fi

log() {
	printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

log "scale-validation repo: ${EOD_REGRESSION_REPO_URL}"
log "scale-validation ref:  ${EOD_REGRESSION_REF}"
log "SCALE version:         ${EOD_REGRESSION_SCALE_VERSION} (ensure=${EOD_REGRESSION_ENSURE_SCALE})"
log "Workdir (per host):    ${EOD_REGRESSION_WORKDIR}"

# ---------------------------------------------------------------------------
# Fail fast, locally, rather than discovering these problems only after
# every host in the fleet has already spent time on a doomed sweep.
# ---------------------------------------------------------------------------

if [[ -z "${EOD_REGRESSION_PLOT_HEATMAP_SCRIPT:-}" ]]; then
	# plot_heatmap.R (and its lsb_common.R dependency) only ever run
	# locally on whichever machine does the collecting -- they are never
	# distributed to the fleet. Default to the real one in the actual EOD
	# checkout, which on this machine lives as a sibling of
	# scale-validation itself. Override explicitly if that's not where it
	# lives on your machine.
	EOD_REGRESSION_PLOT_HEATMAP_SCRIPT="$(dirname "$SCALE_VALIDATION_ROOT")/ExtendedOpenDwarfs/scripts/plot_heatmap.R"
fi

if [[ ! -f "$EOD_REGRESSION_PLOT_HEATMAP_SCRIPT" ]]; then
	echo "error: plot_heatmap.R not found at ${EOD_REGRESSION_PLOT_HEATMAP_SCRIPT}." >&2
	echo "       Set EOD_REGRESSION_PLOT_HEATMAP_SCRIPT explicitly to point at your EOD checkout's copy," >&2
	echo "       or run with EOD_REGRESSION_SKIP_PLOT=1 to only collect results without generating the heatmap." >&2
	if [[ "${EOD_REGRESSION_SKIP_PLOT:-0}" != "1" ]]; then
		exit 1
	fi
fi

# R itself is managed via pixi in the EOD repo (see its pixi.toml), not a
# bare system/conda Rscript -- run everything through `pixi run` from
# that repo's root instead of requiring Rscript directly on PATH.
EOD_REPO_ROOT="$(dirname "$(dirname "$EOD_REGRESSION_PLOT_HEATMAP_SCRIPT")")"

if ! command -v pixi >/dev/null 2>&1; then
	echo "error: pixi not found on this machine -- R (managed via pixi in the EOD repo) cannot run at the end of this script." >&2
	echo "       Install pixi (https://pixi.sh, no root required), or run with EOD_REGRESSION_SKIP_PLOT=1" >&2
	echo "       to only collect results without generating the heatmap." >&2
	if [[ "${EOD_REGRESSION_SKIP_PLOT:-0}" != "1" ]]; then
		exit 1
	fi
fi

for required_path in "ExtendedOpenDwarfs/00-clone.sh" "ExtendedOpenDwarfs/ensure-scale.sh"; do
	if ! git -C "$SCALE_VALIDATION_ROOT" cat-file -e "${EOD_REGRESSION_REF}:${required_path}" 2>/dev/null; then
		echo "error: ${required_path} does not exist at ${EOD_REGRESSION_REF} in ${EOD_REGRESSION_REPO_URL}." >&2
		echo "       Every host clones from EOD_REGRESSION_REPO_URL and checks out EOD_REGRESSION_REF -- if" >&2
		echo "       that repo/ref doesn't contain this file, every host's sweep will fail with 'command not" >&2
		echo "       found' after cloning. Commit and push it, then re-run." >&2
		exit 1
	fi
done

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="${SCALE_VALIDATION_ROOT}/regression-runs/${TIMESTAMP}-scale${EOD_REGRESSION_SCALE_VERSION}"
LOCAL_RESULTS_BASE="${RUN_DIR}/results"
LOG_DIR="${RUN_DIR}/logs"
PLOTS_DIR="${RUN_DIR}/plots"
mkdir -p "$LOCAL_RESULTS_BASE" "$LOG_DIR" "$PLOTS_DIR"

RUN_ENV_PREFIX="APP=${EOD_REGRESSION_APP} SIZE=${EOD_REGRESSION_SIZE} ITERS=${EOD_REGRESSION_ITERS}"

SV_CHECKOUT_DIR="${EOD_REGRESSION_WORKDIR}/scale-validation"
# Nested EOD checkout that scale-validation's own 00-clone.sh creates.
EOD_NESTED_DIR="${SV_CHECKOUT_DIR}/ExtendedOpenDwarfs/ExtendedOpenDwarfs"

# ---------------------------------------------------------------------------
# The command run on every host, local and remote alike. Builds/reuses the
# scale-validation scratch clone, hard-resets it to the pinned ref (safe
# here -- this directory is scratch space, not anyone's real working
# checkout), ensures the requested SCALE version is installed and exports
# SCALE_ROOT to point at it, then runs the paper sweep.
# ---------------------------------------------------------------------------

build_host_command() {
	local ensure_scale_block=""
	if [[ "$EOD_REGRESSION_ENSURE_SCALE" == "1" ]]; then
		# The `\$(cat ...)` below is deliberately escaped: it must be
		# evaluated on the host that actually runs this command (after
		# ensure_scale.sh has written the marker file there), not by this
		# local heredoc right now.
		ensure_scale_block=$(cat <<EOS
SCALE_VERSION="${EOD_REGRESSION_SCALE_VERSION}" ./ensure-scale.sh
export SCALE_ROOT="\$(cat .ensure_scale_last_root)"
echo "Using SCALE_ROOT=\${SCALE_ROOT}"
EOS
)
	fi

	cat <<EOF
set -e
mkdir -p "${EOD_REGRESSION_WORKDIR}"
if [ ! -d "${SV_CHECKOUT_DIR}/.git" ]; then
	git clone "${EOD_REGRESSION_REPO_URL}" "${SV_CHECKOUT_DIR}"
fi
cd "${SV_CHECKOUT_DIR}"
git fetch origin
git checkout --detach "${EOD_REGRESSION_REF}"
git reset --hard "${EOD_REGRESSION_REF}"
cd ExtendedOpenDwarfs
${ensure_scale_block}
# Materialize the nested EOD checkout via this project's own existing
# clone+deps pipeline (00-clone.sh / 01-install-deps.sh), the same way
# it's set up manually -- this directory is a fresh scratch clone on
# first use per host, so nothing here exists until these run. Uses
# whatever repo/ref this project's own versions.txt already pins, same
# as every other project scale-validation manages.
./00-clone.sh
./01-install-deps.sh
cd ExtendedOpenDwarfs
${RUN_ENV_PREFIX} ./scripts/run_scale_eod_paper.sh
EOF
}

HOST_COMMAND="$(build_host_command)"

# ---------------------------------------------------------------------------
# Per-host sweep execution. Each of these writes a status.<host> file
# containing exactly "OK" or "FAILED" -- that file, not the background
# job's own exit code, is the source of truth read back after `wait`,
# since relying on a backgrounded function's exit code across job control
# is fragile in bash.
# ---------------------------------------------------------------------------

run_remote_host() {
	local target="$1"
	local logfile="${LOG_DIR}/${target}.log"
	local statusfile="${RUN_DIR}/status.${target}"

	log "==> [$target] starting remote sweep"

	if timeout "${EOD_REGRESSION_TIMEOUT}" ssh \
			-o BatchMode=yes \
			-o ConnectTimeout=15 \
			-o StrictHostKeyChecking=accept-new \
			"$target" \
			"$HOST_COMMAND" \
			> "$logfile" 2>&1
	then
		log "==> [$target] sweep completed OK (log: $logfile)"
		echo "OK" > "$statusfile"
	else
		local rc=$?
		log "==> [$target] sweep FAILED (exit $rc) -- see $logfile"
		echo "FAILED" > "$statusfile"
	fi
}

run_local_host() {
	local host_label
	host_label="$(hostname -s)"
	local logfile="${LOG_DIR}/${host_label}.log"
	local statusfile="${RUN_DIR}/status.${host_label}"

	log "==> [$host_label] starting LOCAL sweep"

	if timeout "${EOD_REGRESSION_TIMEOUT}" bash -c "$HOST_COMMAND" \
			> "$logfile" 2>&1
	then
		log "==> [$host_label] LOCAL sweep completed OK (log: $logfile)"
		echo "OK" > "$statusfile"
	else
		local rc=$?
		log "==> [$host_label] LOCAL sweep FAILED (exit $rc) -- see $logfile"
		echo "FAILED" > "$statusfile"
	fi
}

# ---------------------------------------------------------------------------
# Launch fleet -- all hosts in parallel. Safe because each Spectral Compute
# host has its own independent filesystem (no shared NFS), so there's no
# contention writing results, installing SCALE, or building EOD binaries
# concurrently across hosts.
# ---------------------------------------------------------------------------

if [[ "$EOD_REGRESSION_SKIP_RUN" == "1" ]]; then
	log "EOD_REGRESSION_SKIP_RUN=1: skipping clone/sync, SCALE-install-check, and build+run steps -- will collect + plot from whatever results/ already exist under ${EOD_REGRESSION_WORKDIR} on each host"
else
	PIDS=()

	if [[ "$EOD_REGRESSION_RUN_LOCAL" == "1" ]]; then
		run_local_host &
		PIDS+=($!)
	fi

	for target in "${REMOTE_TARGETS[@]}"; do
		run_remote_host "$target" &
		PIDS+=($!)
	done

	log "Waiting for ${#PIDS[@]} sweep(s) to complete (per-host timeout ${EOD_REGRESSION_TIMEOUT}s)..."
	for pid in "${PIDS[@]}"; do
		wait "$pid" || true
	done
fi

# ---------------------------------------------------------------------------
# Collect results from every host into one local tree. Kept per-host in
# subdirectories, matching the existing collector script's convention --
# plot_heatmap.R identifies device/benchmark/implementation from the LSB
# filename tags themselves (e.g. lsb.needle_cuda_nvcc_tiny_rtx5090.r0), not
# from directory structure, so this nesting is for human inspection only.
# ---------------------------------------------------------------------------

log "==> Collecting results into ${LOCAL_RESULTS_BASE}"

RSYNC_OPTS=(-az --info=stats1,name1 --partial)

if [[ "$EOD_REGRESSION_RUN_LOCAL" == "1" ]]; then
	local_host_label="$(hostname -s)"
	mkdir -p "${LOCAL_RESULTS_BASE}/${local_host_label}"
	if ! rsync "${RSYNC_OPTS[@]}" "${EOD_NESTED_DIR}/results/" "${LOCAL_RESULTS_BASE}/${local_host_label}/"; then
		log "WARNING: local results copy failed -- ${local_host_label} may be missing from the heatmap"
	fi
fi

for target in "${REMOTE_TARGETS[@]}"; do
	mkdir -p "${LOCAL_RESULTS_BASE}/${target}"
	if ! rsync "${RSYNC_OPTS[@]}" "${target}:${EOD_NESTED_DIR}/results/" "${LOCAL_RESULTS_BASE}/${target}/"; then
		log "WARNING: rsync from ${target} failed -- its results may be partial or missing from this run's heatmap"
	fi
done

# ---------------------------------------------------------------------------
# Generate the heatmap. plot_heatmap.R (and its lsb_common.R dependency)
# only ever runs locally -- keep it alongside this script.
# ---------------------------------------------------------------------------

log "==> Generating heatmap"

PLOT_ARGS=("$LOCAL_RESULTS_BASE" "$PLOTS_DIR" --force-reparse)
if [[ -n "$EOD_REGRESSION_METRIC" ]]; then
	PLOT_ARGS+=("--metric=${EOD_REGRESSION_METRIC}")
fi

HEATMAP_OK=1
if command -v pixi >/dev/null 2>&1; then
	if ! (cd "$EOD_REPO_ROOT" && pixi run Rscript "$EOD_REGRESSION_PLOT_HEATMAP_SCRIPT" "${PLOT_ARGS[@]}") 2>&1 | tee "${LOG_DIR}/plot_heatmap.log"; then
		log "WARNING: heatmap generation failed or exited non-zero -- see ${LOG_DIR}/plot_heatmap.log"
		HEATMAP_OK=0
	fi
else
	log "WARNING: pixi unavailable -- skipping heatmap generation (EOD_REGRESSION_SKIP_PLOT=1 was set)"
	HEATMAP_OK=0
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

log "==> Host status summary:"
FAIL_COUNT=0
TOTAL=0
for f in "${RUN_DIR}"/status.*; do
	[[ -e "$f" ]] || continue
	TOTAL=$((TOTAL + 1))
	status="$(cat "$f")"
	host="$(basename "$f" | sed 's/^status\.//')"
	log "    ${host}: ${status}"
	[[ "$status" == "OK" ]] || FAIL_COUNT=$((FAIL_COUNT + 1))
done

ln -sfn "$RUN_DIR" "${SCALE_VALIDATION_ROOT}/regression-runs/latest"

log "==> Regression run complete: ${RUN_DIR}"
log "    SCALE version: ${EOD_REGRESSION_SCALE_VERSION}"
log "    scale-validation ref tested: ${EOD_REGRESSION_REF}"
log "    Heatmaps:      ${PLOTS_DIR}"
log "    Raw results:   ${LOCAL_RESULTS_BASE}"
log "    Logs:          ${LOG_DIR}"
log "    Latest link:   ${SCALE_VALIDATION_ROOT}/regression-runs/latest"

EXIT_CODE=0

if [[ "$FAIL_COUNT" -gt 0 ]]; then
	log "WARNING: ${FAIL_COUNT}/${TOTAL} host(s) failed to complete their sweep -- heatmap may have missing devices for this run"
	EXIT_CODE=1
fi

if [[ "$HEATMAP_OK" -eq 0 ]]; then
	EXIT_CODE=1
fi

exit "$EXIT_CODE"
