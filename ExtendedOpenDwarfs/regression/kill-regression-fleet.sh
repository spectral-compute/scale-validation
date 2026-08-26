#!/usr/bin/env bash
#
# kill-regression-fleet.sh
#
# Lives in scale-validation/ExtendedOpenDwarfs/regression/, alongside
# run-regression-fleet.sh, compare-scale-versions.sh, ensure-scale.sh, and
# plot-scale-version-diff.R.
#
# Companion "kill switch" for run-regression-fleet.sh. Killing the
# orchestrating process (Ctrl-C, `kill`, a closed terminal, a crash) does
# NOT reliably kill the remote work it started: an `ssh host "command"`
# child dying locally doesn't guarantee the remote command gets torn down
# -- that depends on SSH session/signal-forwarding behavior that varies by
# setup, and is especially unreliable once the remote side is several
# processes deep (ssh's shell -> make -> scripts/odw.py -> the actual
# compiler/benchmark process). The practical result is exactly what you'd
# expect: kill the local script, and a bunch of remote processes keep
# running anyway.
#
# Rather than try to make signal propagation through SSH reliable (fragile
# and hard to verify without live hosts to test every edge case against),
# this takes the simpler, more robust approach of pattern-matching on
# EOD_REGRESSION_WORKDIR (default /tmp/eod-regression) via `pkill -f` on
# each host -- every process this fleet ever starts has that path
# embedded in its command line (cwd, checkout path, or an argument), since
# that's literally where run-regression-fleet.sh's generated script cds
# into and operates from. This works whether the run is still alive, half
# dead, or was killed minutes/hours ago and left orphans behind -- it
# doesn't depend on anything having been set up in advance by the run
# being killed, so it also cleans up runs that predate this script.
#
# Usage:
#   ./kill-regression-fleet.sh
#   EOD_REGRESSION_KILL_CLEAN=1 ./kill-regression-fleet.sh   # also rm -rf the scratch workdir on every host
#
# Reuses the exact same host-list env vars as run-regression-fleet.sh, so
# "which hosts" stays in sync between the two automatically -- set them
# the same way you would to start a run, e.g.
# EOD_REGRESSION_REMOTE_TARGETS to restrict which hosts get touched.
#
# Env vars:
#   EOD_REGRESSION_REMOTE_TARGETS  Default: "alpha epsilon beta andoria"
#   EOD_REGRESSION_RUN_LOCAL       Default: 1
#   EOD_REGRESSION_WORKDIR         Default: "/tmp/eod-regression" -- the
#                                   pkill -f pattern.
#   EOD_REGRESSION_KILL_CLEAN      1 to also delete the scratch workdir on
#                                   every host after killing (git checkout,
#                                   any installed SCALE versions, results --
#                                   everything under EOD_REGRESSION_WORKDIR).
#                                   0 (default) leaves it in place, e.g. for
#                                   inspecting partial results or reusing
#                                   an already-downloaded SCALE install on
#                                   the next run.
#   EOD_REGRESSION_KILL_TIMEOUT    Per-host wall-clock timeout in seconds
#                                   for the kill+cleanup itself (not the
#                                   sweep it's killing). Default: 30 --
#                                   killing should be fast; this exists so
#                                   one unreachable host can't hang the
#                                   whole kill command indefinitely.
#
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ${VAR:=default} treats an explicitly-empty value the same as "unset" and
# re-fills it with the default -- which would silently defeat
# EOD_REGRESSION_REMOTE_TARGETS="" (meaning "no remote hosts, local only").
# ${VAR+x} is true even for an explicitly-empty string, so only a
# genuinely unset var gets the default here.
if [[ -z "${EOD_REGRESSION_REMOTE_TARGETS+x}" ]]; then
	EOD_REGRESSION_REMOTE_TARGETS="alpha epsilon beta andoria"
fi
read -r -a REMOTE_TARGETS <<< "$EOD_REGRESSION_REMOTE_TARGETS"
: "${EOD_REGRESSION_RUN_LOCAL:=1}"
: "${EOD_REGRESSION_WORKDIR:=/tmp/eod-regression}"
: "${EOD_REGRESSION_KILL_CLEAN:=0}"
: "${EOD_REGRESSION_KILL_TIMEOUT:=30}"
log() {
	printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}
log "Killing anything matching workdir: ${EOD_REGRESSION_WORKDIR}"
log "Clean scratch dir after killing:   ${EOD_REGRESSION_KILL_CLEAN}"
# ---------------------------------------------------------------------------
# The command run on every host. SIGTERM first, a brief grace period, then
# SIGKILL for anything still alive -- same shape as `kill` before `kill -9`
# by hand.
#
# IMPORTANT -- self-matching: a naive `pkill -f "$EOD_REGRESSION_WORKDIR"`
# does NOT just match genuine orphaned fleet processes. This very command,
# once handed to `ssh host "..."` or `bash -c "..."`, becomes a process
# whose OWN command line contains EOD_REGRESSION_WORKDIR as plain text
# (it's right there in the script below) -- so pgrep/pkill's self-exclusion
# (which only skips pgrep/pkill's own PID) does nothing to stop it matching
# its own invoking shell, the `timeout`/`ssh` wrapper around it, and every
# sibling host's in-flight invocation of this same script. Confirmed live:
# with zero real target processes running, an unguarded version of this
# still reported "Found matching process(es)" and killed its own
# ssh/timeout/bash siblings instead. KILL_MARKER is a fixed string embedded
# in this script's own text (as a comment) specifically so the exclusion
# check below can tell "this is the kill script itself" apart from "this is
# a genuine orphaned run-regression-fleet.sh process" and only ever act on
# the latter.
#
# IMPORTANT -- kill by process GROUP, not by PID: the actual long-running
# leaf process (the benchmark/compiler invocation deep inside
# run_scale_eod_paper.sh) very often does NOT have EOD_REGRESSION_WORKDIR
# in its OWN argv at all -- it's typically reached via a relative path
# after several `cd`s, so the absolute workdir string only appears in an
# ANCESTOR shell's argv, not its own. Confirmed live: a plain `bash -c "cd
# \$DIR && sleep 300"` process, once its shell exec-optimizes into that
# final command, shows up in ps as bare "sleep 300" -- \$DIR is gone from
# its argv entirely. run-regression-fleet.sh's build_setup_command /
# build_sweep_command each now end with a trailing no-op specifically to
# stop that exec-replace from happening to the OUTERMOST shell (so at
# least one process in the tree reliably keeps the full workdir path in
# its argv for as long as the sweep runs) -- but that guarantees nothing
# about what any FURTHER-nested grandchild's argv looks like. Signalling
# the whole process GROUP (kill -TERM -- -PGID) rather than a single PID
# reaches every descendant regardless of what each one's own argv
# contains, as long as we can find one matching ancestor to read the PGID
# from. (run-regression-fleet.sh's local-host launches use `setsid`
# specifically so each host's job gets its own process group, safe to
# signal this way without also hitting sibling jobs or the orchestrator.)
# ---------------------------------------------------------------------------
KILL_MARKER="__eod_kill_regression_fleet_self__"
build_kill_command() {
	cat <<EOF
set -u
# marker: ${KILL_MARKER}
CANDIDATES="\$(pgrep -f "${EOD_REGRESSION_WORKDIR}" 2>/dev/null || true)"
TARGETS=""
PGIDS=""
for pid in \$CANDIDATES; do
	if ! ps -p "\$pid" -o args= 2>/dev/null | grep -q "${KILL_MARKER}"; then
		TARGETS="\$TARGETS \$pid"
		pgid="\$(ps -p "\$pid" -o pgid= 2>/dev/null | tr -d ' ')"
		if [ -n "\$pgid" ]; then
			case " \$PGIDS " in
				*" \$pgid "*) ;;  # already have this group
				*) PGIDS="\$PGIDS \$pgid" ;;
			esac
		fi
	fi
done
TARGETS="\$(echo \$TARGETS)"
PGIDS="\$(echo \$PGIDS)"
if [ -n "\$TARGETS" ]; then
	echo "Found matching process(es):"
	for pid in \$TARGETS; do
		ps -p "\$pid" -o pid=,pgid=,args= 2>/dev/null || true
	done
	echo "Signalling process group(s):\$PGIDS"
	for pgid in \$PGIDS; do
		kill -TERM -- "-\$pgid" 2>/dev/null || true
	done
	# Belt-and-braces: also signal the matched PIDs directly, in case any
	# of them ended up in a group we couldn't resolve above (e.g. it exited
	# between the pgrep and the ps lookup).
	kill -TERM \$TARGETS 2>/dev/null || true
	sleep 2
	STILL=""
	for pid in \$TARGETS; do
		if kill -0 "\$pid" 2>/dev/null; then
			STILL="\$STILL \$pid"
		fi
	done
	if [ -n "\$STILL" ]; then
		for pgid in \$PGIDS; do
			kill -KILL -- "-\$pgid" 2>/dev/null || true
		done
		echo "Still alive after SIGTERM -- sending SIGKILL"
		kill -KILL \$STILL 2>/dev/null || true
	fi
	echo "Kill pass complete."
else
	echo "No matching processes found."
fi
if [ "${EOD_REGRESSION_KILL_CLEAN}" = "1" ]; then
	if [ -d "${EOD_REGRESSION_WORKDIR}" ]; then
		echo "Removing scratch workdir: ${EOD_REGRESSION_WORKDIR}"
		rm -rf "${EOD_REGRESSION_WORKDIR}"
	else
		echo "Scratch workdir already absent: ${EOD_REGRESSION_WORKDIR}"
	fi
fi
exit 0
EOF
}
KILL_COMMAND="$(build_kill_command)"
kill_remote_host() {
	local target="$1"
	log "==> [$target] checking for matching processes..."
	local output
	if output="$(timeout "${EOD_REGRESSION_KILL_TIMEOUT}" ssh \
			-o BatchMode=yes \
			-o ConnectTimeout=15 \
			-o StrictHostKeyChecking=accept-new \
			"$target" \
			"$KILL_COMMAND" 2>&1)"
	then
		log "==> [$target] done:"
		echo "$output" | sed "s/^/    [$target] /"
	else
		log "==> [$target] FAILED to connect or run cleanup (host may be down/unreachable) -- see below"
		echo "$output" | sed "s/^/    [$target] /"
	fi
}
kill_local_host() {
	local host_label
	host_label="$(hostname -s)"
	log "==> [$host_label] (local) checking for matching processes..."
	local output
	if output="$(timeout "${EOD_REGRESSION_KILL_TIMEOUT}" bash -c "$KILL_COMMAND" 2>&1)"; then
		log "==> [$host_label] done:"
		echo "$output" | sed "s/^/    [$host_label] /"
	else
		log "==> [$host_label] FAILED to run cleanup -- see below"
		echo "$output" | sed "s/^/    [$host_label] /"
	fi
}
PIDS=()
if [[ "$EOD_REGRESSION_RUN_LOCAL" == "1" ]]; then
	kill_local_host &
	PIDS+=($!)
fi
for target in "${REMOTE_TARGETS[@]}"; do
	kill_remote_host "$target" &
	PIDS+=($!)
done
log "Waiting for ${#PIDS[@]} host(s) to finish cleanup (per-host timeout ${EOD_REGRESSION_KILL_TIMEOUT}s)..."
for pid in "${PIDS[@]}"; do
	wait "$pid" || true
done
log "Done. If a host reported FAILED above (unreachable), it may still have orphaned processes -- re-run once it's reachable, or clean it up manually."
