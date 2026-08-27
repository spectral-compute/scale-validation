#!/usr/bin/env bash
#
# run_regression_fleet.sh
#
# Lives in scale-validation/ExtendedOpenDwarfs/regression/, alongside
# ensure-scale.sh, compare-scale-versions.sh, and
# plot-scale-version-diff.R -- deliberately one level below
# scale-validation/ExtendedOpenDwarfs/ (which holds 00-clone.sh,
# 01-install-deps.sh, etc., and is NOT itself inside the public upstream
# ANU-HPC ExtendedOpenDwarfs checkout -- that's the NESTED
# ExtendedOpenDwarfs/ExtendedOpenDwarfs/ directory 00-clone.sh creates).
# Living in regression/ specifically (rather than directly alongside the
# 00-03 numbered scripts) matters for a second reason beyond tidiness:
# scale-validation's test.sh driver globs "${TEST_DIR}/${TEST}"/*.sh
# non-recursively and runs everything it finds with set -o errexit as
# part of an ordinary per-project smoke test. This script (and the rest
# of the regression tooling) is not that -- it's a deliberately-triggered,
# multi-host, multi-hour sweep -- so it lives one directory level below
# where that glob reaches.
#
# Farms scripts/run_scale_eod_regression.sh (see NOTE below) out to every
# configured Spectral Compute host, waits for each host's sweep to finish
# (independently -- one host's failure or timeout does not block the
# others), rsyncs every host's results/ back to a single timestamped local
# directory, and runs plot_heatmap.R against the combined dataset to
# produce the SCALE-vs-native heatmap.
#
# Hosts are all Spectral Compute machines (trill, benzar, epsilon, beta,
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
# each host before sweeping (see ensure-scale.sh, alongside this script).
# Different SCALE versions install side by side under the same scratch
# checkout, so toggling EOD_REGRESSION_SCALE_VERSION between runs -- e.g.
# to compare 1.7.1 against 1.7.2 -- only pays a download cost the first
# time each version is used on a given host.
#
# NOTE on run_scale_eod_regression.sh: this script shells out to
# scripts/run_scale_eod_regression.sh (inside the nested EOD checkout,
# same location run_scale_eod_paper.sh already lived at -- no directory
# fix was actually needed, that was speculation before either script's
# contents had been reviewed) for the actual per-device sweep. It knows
# how to fan a single host out across multiple physical GPUs with the
# correct arch/backend/compiler/visible-device pairing for each --
# necessary on multi-GPU boxes like trill and benzar.
#
# This is a SEPARATE script from run_scale_eod_paper.sh, not a renamed or
# relocated version of it. run_scale_eod_paper.sh stays as-is (it still
# reproduces the paper's original fixed-host results, including ORNL
# machines -- zenith, milan0, hudson, faraday, cousteau, explorer, troi --
# that are not part of, and will never be added to, this regression
# fleet). run_scale_eod_regression.sh targets only the current regression
# fleet hosts and must be committed at
# scripts/run_scale_eod_regression.sh in the EOD repo/ref this script
# checks out (EOD_REGRESSION_REPO_URL / EOD_REGRESSION_REF) -- 00-clone.sh
# does a fresh clone every run, so an uncommitted local-only copy will not
# survive onto any fleet host.
#
# NOTE on plot_heatmap.R: only ever runs locally, on whichever machine
# collects results -- it is never distributed to the fleet hosts. Keep it
# (and its lsb_common.R dependency) alongside this script.
#
# Usage:
#   ./run_regression_fleet.sh
#   EOD_REGRESSION_SCALE_VERSION=1.7.1 ./run_regression_fleet.sh
#   EOD_REGRESSION_SCALE_VERSION=1.7.2 ./run_regression_fleet.sh
#   # Distribute a proprietary local build (not on pkgs.scale-lang.com) to
#   # every host instead of downloading a named release:
#   EOD_REGRESSION_SCALE_VERSION=master \
#   EOD_REGRESSION_LOCAL_SCALE_BUILD=/home/beau/roll-scale/scale-wip \
#     ./run_regression_fleet.sh
#
# Configuration is via environment variables (all optional, sane defaults
# shown). This intentionally mirrors the style of setup-backends.sh /
# runner.sh rather than introducing a new flag-parsing convention:
#
#   EOD_REGRESSION_REMOTE_TARGETS
#       Space-separated list of ssh destinations to farm the sweep out to.
#       Plain hostnames by default -- no username is prepended, so ssh
#       resolves it the normal way (current user, or ~/.ssh/config).
#       Default: "benzar epsilon beta andoria risa"
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
#       ExtendedOpenDwarfs/ directory, per ensure-scale.sh's own default.
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
#       1 (default) to run ensure-scale.sh on each host before the sweep,
#       installing the requested SCALE_VERSION if it's missing, and
#       exporting SCALE_ROOT to point at it. 0 to skip this entirely and
#       use whatever SCALE_ROOT (or setup-backends.sh's own default) is
#       already in effect on each host.
#
#   EOD_REGRESSION_SCALE_VERSION
#       Which SCALE version to ensure/use on every host, e.g. "1.7.1",
#       "1.7.2", or "latest". See https://pkgs.scale-lang.com/tar/ for the
#       full list of available versions. Default: "latest"
#       Only meaningful when EOD_REGRESSION_ENSURE_SCALE=1 and
#       EOD_REGRESSION_LOCAL_SCALE_BUILD is unset. Still used as the
#       *label* for this run's regression-runs/ directory and heatmap
#       filenames either way (e.g. "master", "wip-foo") -- see
#       EOD_REGRESSION_LOCAL_SCALE_BUILD below.
#
#   EOD_REGRESSION_LOCAL_SCALE_BUILD
#       Absolute path, on THIS machine (the one invoking this script), to
#       an already-built SCALE install directory (containing bin/scaleenv)
#       that isn't published to pkgs.scale-lang.com -- e.g. a proprietary
#       local build off a WIP branch, where source can't be shared and so
#       ensure-scale.sh's normal tarball download can't be used at all.
#       When set, this takes priority over EOD_REGRESSION_ENSURE_SCALE:
#       ensure-scale.sh is skipped entirely, and instead this exact
#       directory is rsync'd out to every host taking part in the sweep
#       (local and remote alike), landing at the same
#       scale-<EOD_REGRESSION_SCALE_VERSION>-Linux path a normal
#       ensure-scale.sh install would have used -- so SCALE_ROOT, the
#       .ensure_scale_last_root marker file, and everything downstream
#       that reads either one stays identical in shape to the normal path.
#       Pair this with a distinct EOD_REGRESSION_SCALE_VERSION label (e.g.
#       "master") so the resulting run doesn't collide with, or get
#       confused for, an actual downloaded release. Unset by default.
#
#   EOD_REGRESSION_TIMEOUT
#       Per-host wall-clock timeout in seconds, covering the clone/sync,
#       SCALE install check (if enabled), and the sweep itself.
#       Default: 14400 (4 hours). A stuck host is killed and marked
#       FAILED rather than hanging the whole fleet run indefinitely.
#
#   EOD_REGRESSION_APP / EOD_REGRESSION_SIZE / EOD_REGRESSION_ITERS
#       Passed through as APP/SIZE/ITERS to run_scale_eod_regression.sh on
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
# This script now lives in .../ExtendedOpenDwarfs/regression/, one level
# below .../ExtendedOpenDwarfs/ -- scale-validation's own root is
# therefore two levels up from here, not one.
SCALE_VALIDATION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# ${VAR:=default} treats an explicitly-empty value the same as "unset" and
# re-fills it with the default -- which silently defeats
# EOD_REGRESSION_REMOTE_TARGETS="" (used to mean "no remote hosts, local
# only"; this is a real command from prior usage, not a hypothetical).
# ${VAR+x} is true even for an explicitly-empty string, so only a
# genuinely unset var gets the default here; an explicit "" is honored.
if [[ -z "${EOD_REGRESSION_REMOTE_TARGETS+x}" ]]; then
	EOD_REGRESSION_REMOTE_TARGETS="benzar epsilon beta andoria"  # risa omitted: it has the same hardware as trill
fi
read -r -a REMOTE_TARGETS <<< "$EOD_REGRESSION_REMOTE_TARGETS"
: "${EOD_REGRESSION_RUN_LOCAL:=1}"
: "${EOD_REGRESSION_WORKDIR:=/tmp/eod-regression}"
: "${EOD_REGRESSION_ENSURE_SCALE:=1}"
: "${EOD_REGRESSION_SCALE_VERSION:=latest}"
: "${EOD_REGRESSION_TIMEOUT:=14400}"
: "${EOD_REGRESSION_APP:=all}"
: "${EOD_REGRESSION_SIZE:=all}"
: "${EOD_REGRESSION_ITERS:=5}"
: "${EOD_REGRESSION_SKIP_RUN:=0}"
: "${EOD_REGRESSION_METRIC:=}"
: "${EOD_REGRESSION_LOCAL_SCALE_BUILD:=}"
if [[ -n "$EOD_REGRESSION_LOCAL_SCALE_BUILD" ]]; then
	if [[ ! -x "${EOD_REGRESSION_LOCAL_SCALE_BUILD}/bin/scaleenv" ]]; then
		echo "error: EOD_REGRESSION_LOCAL_SCALE_BUILD (${EOD_REGRESSION_LOCAL_SCALE_BUILD}) does not look like a SCALE install -- ${EOD_REGRESSION_LOCAL_SCALE_BUILD}/bin/scaleenv not found or not executable." >&2
		exit 1
	fi
	# Resolve to an absolute path once, up front -- this gets embedded into
	# an rsync command run later, on a potentially different cwd (inside a
	# backgrounded function), so a relative path given by the caller would
	# silently break.
	EOD_REGRESSION_LOCAL_SCALE_BUILD="$(cd "$EOD_REGRESSION_LOCAL_SCALE_BUILD" && pwd)"
fi
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
# Best-effort auto-cleanup on Ctrl-C / SIGTERM: killing THIS process does
# not reliably kill the remote work it started (an ssh child dying locally
# doesn't guarantee the remote command gets torn down), so on a graceful
# interrupt, proactively run the same kill-everything logic
# kill-regression-fleet.sh exposes standalone. This is deliberately
# best-effort only -- it cannot catch SIGKILL (`kill -9`, which bypasses
# traps entirely by design), a closed terminal, or a crash. For those,
# kill-regression-fleet.sh still needs to be run by hand afterward -- that
# script is safe to (re-)run any time regardless of whether this trap
# already ran, since it pattern-matches on the workdir rather than
# depending on any state this run left behind.
trap 'log "Caught interrupt -- attempting to kill in-flight remote/local sweeps via kill-regression-fleet.sh..."; "${SCRIPT_DIR}/kill-regression-fleet.sh" || true; exit 130' INT TERM
log "scale-validation repo: ${EOD_REGRESSION_REPO_URL}"
log "scale-validation ref:  ${EOD_REGRESSION_REF}"
if [[ -n "$EOD_REGRESSION_LOCAL_SCALE_BUILD" ]]; then
	log "SCALE version:         ${EOD_REGRESSION_SCALE_VERSION} (distributing local build: ${EOD_REGRESSION_LOCAL_SCALE_BUILD})"
else
	log "SCALE version:         ${EOD_REGRESSION_SCALE_VERSION} (ensure=${EOD_REGRESSION_ENSURE_SCALE})"
fi
log "Workdir (per host):    ${EOD_REGRESSION_WORKDIR}"
# ---------------------------------------------------------------------------
# Fail fast, locally, rather than discovering these problems only after
# every host in the fleet has already spent time on a doomed sweep.
# ---------------------------------------------------------------------------
if [[ -z "${EOD_REGRESSION_PLOT_HEATMAP_SCRIPT:-}" ]]; then
	# plot_heatmap.R (and its lsb_common.R dependency) only ever run
	# locally on whichever machine does the collecting -- they are never
	# distributed to the fleet. Default to the real one in the actual EOD
	# checkout, which is a SEPARATE, standalone clone of ExtendedOpenDwarfs
	# living as a sibling of scale-validation itself
	# (i.e. dirname(scale-validation)/ExtendedOpenDwarfs/scripts/) -- NOT
	# the ephemeral nested checkout 00-clone.sh recreates fresh inside
	# scale-validation/ExtendedOpenDwarfs/ExtendedOpenDwarfs/ for each
	# fleet host's own scratch workdir. This default is unaffected by
	# where this script itself lives (regression/ or otherwise), since
	# it's computed relative to SCALE_VALIDATION_ROOT, not $SCRIPT_DIR.
	# Override explicitly if that's not where it lives on your machine.
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
for required_path in "ExtendedOpenDwarfs/00-clone.sh" "ExtendedOpenDwarfs/regression/ensure-scale.sh"; do
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
# Where a locally-built SCALE install (EOD_REGRESSION_LOCAL_SCALE_BUILD)
# lands on each host -- same relative location a normal ensure-scale.sh
# install would use (a sibling of 00-clone.sh, i.e. directly inside the
# OUTER ExtendedOpenDwarfs/, not the nested checkout), just placed there
# by rsync instead of by download.
REMOTE_SCALE_TARGET="${SV_CHECKOUT_DIR}/ExtendedOpenDwarfs/scale-${EOD_REGRESSION_SCALE_VERSION}-Linux"
# ---------------------------------------------------------------------------
# The commands run on every host, local and remote alike, split into two
# phases rather than the single combined script this used to be:
#
#   build_setup_command  -- clone/reset the scale-validation scratch
#                            checkout. This is what CREATES the outer
#                            ExtendedOpenDwarfs/ directory on each host.
#   build_sweep_command   -- everything after that: get SCALE in place
#                            (download via ensure-scale.sh, distribute a
#                            local build, or use whatever's already there),
#                            materialize the nested EOD checkout, and run
#                            the sweep.
#
# The split exists specifically for EOD_REGRESSION_LOCAL_SCALE_BUILD: that
# mode needs to rsync a local SCALE build into
# ExtendedOpenDwarfs/scale-<version>-Linux/ on each host BETWEEN these two
# phases -- the target directory doesn't exist until build_setup_command's
# `git clone` creates it (git clone refuses to clone into a non-empty
# directory, so the build can't be pushed there first), but
# build_sweep_command needs it already in place before it runs. When
# EOD_REGRESSION_LOCAL_SCALE_BUILD is unset, both phases still run
# back-to-back as before -- see run_remote_host/run_local_host below.
# ---------------------------------------------------------------------------
build_setup_command() {
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
: # deliberately not the tail command -- see build_sweep_command's own
  # comment on this same trick, just below.
EOF
}
build_sweep_command() {
	local ensure_scale_block=""
	if [[ -n "$EOD_REGRESSION_LOCAL_SCALE_BUILD" ]]; then
		# The build itself was already rsync'd into place (into
		# REMOTE_SCALE_TARGET) between build_setup_command and this, by
		# run_remote_host/run_local_host -- see their own comments. Just
		# point SCALE_ROOT at it and write the same marker file
		# ensure-scale.sh itself would (same location: cwd here is already
		# the outer ExtendedOpenDwarfs/), so anything downstream that reads
		# .ensure_scale_last_root doesn't need to know SCALE came from a
		# push rather than a download.
		ensure_scale_block=$(cat <<EOS
export SCALE_ROOT="\$(pwd)/scale-${EOD_REGRESSION_SCALE_VERSION}-Linux"
echo "\${SCALE_ROOT}" > .ensure_scale_last_root
echo "Using locally-distributed SCALE_ROOT=\${SCALE_ROOT}"
EOS
)
	elif [[ "$EOD_REGRESSION_ENSURE_SCALE" == "1" ]]; then
		# The `\$(cat ...)` below is deliberately escaped: it must be
		# evaluated on the host that actually runs this command (after
		# ensure-scale.sh has written the marker file there), not by this
		# local heredoc right now. ensure-scale.sh lives in regression/
		# now, one level below where this cwd (ExtendedOpenDwarfs/) sits.
		ensure_scale_block=$(cat <<EOS
SCALE_VERSION="${EOD_REGRESSION_SCALE_VERSION}" ./regression/ensure-scale.sh
export SCALE_ROOT="\$(cat .ensure_scale_last_root)"
echo "Using SCALE_ROOT=\${SCALE_ROOT}"
EOS
)
	fi
	cat <<EOF
set -e
cd "${SV_CHECKOUT_DIR}/ExtendedOpenDwarfs"
${ensure_scale_block}
# Materialize the nested EOD checkout via this project's own existing
# clone+deps pipeline (00-clone.sh / 01-install-deps.sh), the same way
# it's set up manually. 00-clone.sh's own clone helpers do a plain 'git
# clone' with no handling for the destination already existing -- fine
# for scale-validation's normal usage (a fresh workdir per invocation),
# but this fleet script deliberately reuses a persistent workdir across
# runs for speed, so a nested checkout left over from a prior (possibly
# failed) run causes 'git clone' to fail outright on every subsequent
# run. Remove it first every time so 00-clone.sh always starts clean,
# regardless of what a previous run left behind.
rm -rf ExtendedOpenDwarfs
./00-clone.sh
./01-install-deps.sh
cd ExtendedOpenDwarfs
${RUN_ENV_PREFIX} ./scripts/run_scale_eod_regression.sh
: # NOT a no-op in practice: when a command is the literal last thing a
  # "bash -c '...'" (or sshd-invoked "sh -c '...'") script will ever run,
  # bash/sh may skip forking and exec() straight into it instead --
  # replacing that process's own argv with just
  # "./scripts/run_scale_eod_regression.sh" (or whatever
  # run_scale_eod_regression.sh itself execs into next), silently dropping every "cd \$WORKDIR/..."
  # this heredoc built up. kill-regression-fleet.sh's pkill -f
  # \$EOD_REGRESSION_WORKDIR then has nothing left to match on that
  # process -- confirmed empirically: without this trailing no-op, a
  # spawned "bash -c \"cd \$DIR && sleep 300\"" process's own argv, once
  # exec-optimized, showed up as bare "sleep 300", with \$DIR nowhere in
  # it. Keeping a command after the real one here forces bash/sh to fork
  # and keep the whole script (workdir path included) as this process's
  # argv for as long as the sweep runs, which is exactly what
  # kill-regression-fleet.sh needs to be able to find and kill it later.
EOF
}
SETUP_COMMAND="$(build_setup_command)"
SWEEP_COMMAND="$(build_sweep_command)"
# ---------------------------------------------------------------------------
# Per-host sweep execution. Each of these writes a status.<host> file
# containing exactly "OK" or "FAILED" -- that file, not the background
# job's own exit code, is the source of truth read back after `wait`,
# since relying on a backgrounded function's exit code across job control
# is fragile in bash.
#
# NOTE on timeouts in EOD_REGRESSION_LOCAL_SCALE_BUILD mode: each of the
# (now up to four) steps -- setup, mkdir, rsync, sweep -- gets its own
# EOD_REGRESSION_TIMEOUT budget rather than one shared budget for the
# whole host, unlike the normal (non-local-build) path where setup+sweep
# run as a single ssh call under one timeout. That means worst-case time
# for a host is now higher than EOD_REGRESSION_TIMEOUT alone in this mode.
# Simpler and safer than trying to thread one shared deadline across a
# multi-step remote+local sequence; raise EOD_REGRESSION_TIMEOUT if a
# large local SCALE build's transfer alone needs more room.
# ---------------------------------------------------------------------------
run_remote_host() {
	local target="$1"
	local logfile="${LOG_DIR}/${target}.log"
	local statusfile="${RUN_DIR}/status.${target}"
	log "==> [$target] starting remote sweep"
	# ServerAliveInterval/CountMax: a multi-hour sweep spends long stretches
	# silently computing on the remote GPU between printed lines -- NAT
	# gateways/firewalls commonly kill SSH connections they judge "idle"
	# after some timeout, even though the session is genuinely still
	# alive and working. That shows up as a mid-run "client_loop: send
	# disconnect: Broken pipe" with no application-side cause at all --
	# confirmed live on beta (cwt/hip/small, 3.8 iterations in, mid-sweep,
	# no error from the benchmark itself). Sending a keepalive probe every
	# 60s (tolerating up to 10 missed = ~10 minutes before genuinely
	# giving up) keeps the connection looking active to anything in
	# between, without masking a real, prolonged network/host failure.
	local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=60 -o ServerAliveCountMax=10)
	if (
			set -e
			if [[ -n "$EOD_REGRESSION_LOCAL_SCALE_BUILD" ]]; then
				timeout "${EOD_REGRESSION_TIMEOUT}" ssh "${ssh_opts[@]}" "$target" "$SETUP_COMMAND"
				timeout "${EOD_REGRESSION_TIMEOUT}" ssh "${ssh_opts[@]}" "$target" "mkdir -p '${REMOTE_SCALE_TARGET}'"
				log "==> [$target] pushing local SCALE build (${EOD_REGRESSION_LOCAL_SCALE_BUILD}) -> ${target}:${REMOTE_SCALE_TARGET}"
				timeout "${EOD_REGRESSION_TIMEOUT}" rsync -az --delete -e "ssh ${ssh_opts[*]}" \
					"${EOD_REGRESSION_LOCAL_SCALE_BUILD}/" "${target}:${REMOTE_SCALE_TARGET}/"
				timeout "${EOD_REGRESSION_TIMEOUT}" ssh "${ssh_opts[@]}" "$target" "$SWEEP_COMMAND"
			else
				timeout "${EOD_REGRESSION_TIMEOUT}" ssh "${ssh_opts[@]}" "$target" "${SETUP_COMMAND}
${SWEEP_COMMAND}"
			fi
		) > "$logfile" 2>&1
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
	# setsid: puts each local host's bash -c invocation in its own new
	# process group, separate from run-regression-fleet.sh's own group and
	# from every other backgrounded host job. Local jobs here are launched
	# as plain background jobs (`&`) rather than through ssh, so without
	# this they'd inherit THIS script's own process group -- meaning
	# kill-regression-fleet.sh's process-group kill (see its own comments)
	# would risk hitting run-regression-fleet.sh itself, or unrelated
	# sibling host jobs, instead of just this one host's sweep tree.
	if (
			set -e
			if [[ -n "$EOD_REGRESSION_LOCAL_SCALE_BUILD" ]]; then
				timeout "${EOD_REGRESSION_TIMEOUT}" setsid bash -c "$SETUP_COMMAND"
				mkdir -p "${REMOTE_SCALE_TARGET}"
				log "==> [$host_label] placing local SCALE build (${EOD_REGRESSION_LOCAL_SCALE_BUILD}) -> ${REMOTE_SCALE_TARGET}"
				timeout "${EOD_REGRESSION_TIMEOUT}" rsync -az --delete \
					"${EOD_REGRESSION_LOCAL_SCALE_BUILD}/" "${REMOTE_SCALE_TARGET}/"
				timeout "${EOD_REGRESSION_TIMEOUT}" setsid bash -c "$SWEEP_COMMAND"
			else
				timeout "${EOD_REGRESSION_TIMEOUT}" setsid bash -c "${SETUP_COMMAND}
${SWEEP_COMMAND}"
			fi
		) > "$logfile" 2>&1
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
