# Makefile for scale-validation/ExtendedOpenDwarfs/regression/.
#
# Thin wrapper around the scripts in this directory -- all the actual
# configuration (which hosts, which SCALE version, app/size/iters, etc.)
# is still done via the EOD_REGRESSION_* env vars those scripts already
# document in their own headers. This Makefile doesn't introduce a second,
# parallel configuration mechanism: any EOD_REGRESSION_* variable can be
# set the normal `make target VAR=value` way and it reaches the recipe's
# shell environment automatically (this is standard GNU Make behaviour for
# command-line-assigned variables, not something special to this file).
#
# Usage:
#   make run                                  # ./run-regression-fleet.sh with default env
#   EOD_REGRESSION_SCALE_VERSION=1.7.2 make run
#   make kill                                 # kill any in-flight/orphaned fleet processes, keep scratch dirs
#   make clean                                # kill, then also rm -rf the scratch workdir on every host
#
#   make ci VERSION=1.7.2                                       # MODE defaults to native
#   make ci MODE=version-diff VERSION=scale-master BASELINE=1.7.2 \
#           EOD_REGRESSION_LOCAL_SCALE_BUILD=/home/you/roll-scale/scale-wip
#   make ci MODE=both VERSION=1.7.3 BASELINE=1.7.2 EOD_REGRESSION_SIZE=tiny
#
#   make ci-smoke MODE=version-diff VERSION=scale-master BASELINE=1.7.2 \
#           EOD_REGRESSION_LOCAL_SCALE_BUILD=/home/you/roll-scale/scale-wip
#           # same as `ci`, but forces a fast local-only/tiny/1-iteration run --
#           # use this first when standing up a new CI job, before trusting it
#           # with a full multi-host sweep.
#
#   make ci-release VERSION=1.7.3 BASELINE=1.7.2
#           # alias for `make ci MODE=both` -- "does this candidate version
#           # regress against the last published release, AND how does it
#           # look against native toolchains on its own". The release-prep
#           # question this whole thing exists for.
#
#   make ci-local VERSION=my-wip-build EOD_REGRESSION_LOCAL_SCALE_BUILD=/home/you/roll-scale/scale-wip
#           # alias for `make ci MODE=native` -- the CONVENTIONAL SCALE-vs-native
#           # heatmap (plot_heatmap.R: is SCALE faster/slower than nvcc/hipcc on
#           # AMD and NVIDIA systems), but against a custom/local SCALE build
#           # instead of a published release. Just native mode with
#           # EOD_REGRESSION_LOCAL_SCALE_BUILD's requirement enforced -- no
#           # BASELINE needed, this isn't a version-diff.
#
#   make archive-comparison BASELINE=1.7.2 VERSION=1.7.3-rc
#           # bundles both builds' already-archived full plot_lsb.R
#           # box-and-whisker plot sets, plus the most recent whole-benchmark
#           # + per-region diff heatmaps/CSVs for this pair, into one
#           # tarball -- for handing off to compiler devs doing a point-wise
#           # comparison. Doesn't run or re-plot anything -- see
#           # compare-scale-versions.sh's own --archive header for what it
#           # requires to already exist.
#
#   make regression-report BASELINE=1.7.2 VERSION=1.7.3-rc \
#           CANDIDATE_LABEL=nightly-b4a9776f9817
#           # the one-shot version of the above: --replot (regenerates the
#           # whole-benchmark + per-region diffs and re-archives plots-full/
#           # for both sides) immediately followed by --archive, in a single
#           # command. BASELINE/VERSION must already have completed runs
#           # under regression-runs/ -- run `make ci`/`ci-release` first if
#           # either side hasn't been run yet. BASELINE_LABEL/
#           # CANDIDATE_LABEL are optional and only change display
#           # text/filenames, not which runs get looked up.
#
# See run-regression-ci.sh's own header for exactly what each MODE
# produces and where (regression-runs/ci-latest/, overwritten each run --
# stable path for a CI artifact-upload step, plus SUMMARY.md).
#
SHELL := /usr/bin/env bash
.PHONY: run kill clean ci ci-smoke ci-release ci-local archive-comparison regression-report help

MODE ?= native
VERSION ?=
BASELINE ?=
BASELINE_LABEL ?=
CANDIDATE_LABEL ?=
ARCHIVE_OUT ?=

run:
	./run-regression-fleet.sh

kill:
	./kill-regression-fleet.sh

clean:
	EOD_REGRESSION_KILL_CLEAN=1 ./kill-regression-fleet.sh

# Guards against the most common way to get this wrong before it costs a
# multi-host fleet run's worth of time: VERSION must be set, BASELINE must
# be set for anything except MODE=native, and a VERSION that isn't a plain
# released number (e.g. "scale-master", a local dev build's own label)
# needs EOD_REGRESSION_LOCAL_SCALE_BUILD pointing at that build -- ensure-scale.sh
# has no other way to install it (it only knows how to download real
# releases from pkgs.scale-lang.com).
ci:
	@if [ -z "$(VERSION)" ]; then \
		echo "error: VERSION is required, e.g. make ci VERSION=1.7.2" >&2; \
		exit 1; \
	fi
	@if [ "$(MODE)" != "native" ] && [ -z "$(BASELINE)" ]; then \
		echo "error: BASELINE is required for MODE=$(MODE), e.g. make ci MODE=$(MODE) VERSION=$(VERSION) BASELINE=1.7.2" >&2; \
		exit 1; \
	fi
	@if ! echo "$(VERSION)" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$$' && [ -z "$$EOD_REGRESSION_LOCAL_SCALE_BUILD" ]; then \
		if echo "$(VERSION)" | grep -q '/'; then \
			echo "error: VERSION='$(VERSION)' looks like a path, not a version label." >&2; \
			echo "       VERSION is only ever a NAME -- used to label this run's output directory and plot" >&2; \
			echo "       titles -- it is never treated as a filesystem path, even if it looks like one." >&2; \
			echo "       To test a local/compiled build, keep VERSION a short label and separately point" >&2; \
			echo "       EOD_REGRESSION_LOCAL_SCALE_BUILD at the build directory itself (which must contain" >&2; \
			echo "       bin/scaleenv, the same layout a downloaded release has):" >&2; \
			echo "         make ci-release VERSION=1.7.3-rc BASELINE=$(BASELINE) EOD_REGRESSION_LOCAL_SCALE_BUILD=$(VERSION)" >&2; \
		else \
			echo "error: VERSION='$(VERSION)' doesn't look like a published SCALE release (expected e.g. 1.7.2)." >&2; \
			echo "       ensure-scale.sh can only download real releases -- for a local/dev build, also set" >&2; \
			echo "       EOD_REGRESSION_LOCAL_SCALE_BUILD=/path/to/that/build (it only ever applies to the" >&2; \
			echo "       candidate side of a version-diff, never the baseline -- see compare-scale-versions.sh)." >&2; \
		fi; \
		exit 1; \
	fi
	./run-regression-ci.sh $(MODE) $(VERSION) $(BASELINE)

ci-smoke:
	EOD_REGRESSION_REMOTE_TARGETS="" EOD_REGRESSION_SIZE=tiny EOD_REGRESSION_ITERS=1 \
		$(MAKE) ci MODE=$(MODE) VERSION=$(VERSION) BASELINE=$(BASELINE)

ci-release:
	$(MAKE) ci MODE=both VERSION=$(VERSION) BASELINE=$(BASELINE)

# The conventional SCALE-vs-native heatmap (native mode -- no BASELINE, not
# a version-diff), but against a custom/local SCALE build instead of a
# published release. MODE is forced to native regardless of what's passed,
# since that's the whole point of this target; ci's own VERSION-required
# guard still applies (still used as the run's label/heatmap title), and
# this adds the one check that actually matters here -- there's no point
# in "ci-local" without a local build to point at.
ci-local:
	@if [ -z "$$EOD_REGRESSION_LOCAL_SCALE_BUILD" ]; then \
		echo "error: ci-local is for the conventional SCALE-vs-native heatmap against a custom/local SCALE build, not a published release." >&2; \
		echo "       Set EOD_REGRESSION_LOCAL_SCALE_BUILD=/path/to/that/build (must contain bin/scaleenv)." >&2; \
		echo "       For a published release instead, use: make ci VERSION=1.7.2" >&2; \
		exit 1; \
	fi
	$(MAKE) ci MODE=native VERSION=$(VERSION)

# Bundles both builds' already-archived full plot_lsb.R box-and-whisker
# plot sets (plots-full/, produced automatically alongside any normal or
# --replot compare-scale-versions.sh call) plus the most recent
# whole-benchmark + per-region diff heatmaps/CSVs for this exact pair
# into one tarball -- for handing off to compiler devs doing a point-wise
# comparison. Does not run or re-plot anything itself; BASELINE and
# VERSION must already have completed runs (and ideally a diff between
# them) under regression-runs/.
archive-comparison:
	@if [ -z "$(BASELINE)" ] || [ -z "$(VERSION)" ]; then \
		echo "error: archive-comparison needs both BASELINE and VERSION, e.g. make archive-comparison BASELINE=1.7.2 VERSION=1.7.3-rc" >&2; \
		exit 1; \
	fi
	./compare-scale-versions.sh --archive $(BASELINE) $(VERSION) $(if $(ARCHIVE_OUT),--out=$(ARCHIVE_OUT))

# One-shot version of --replot followed by --archive: regenerates the
# whole-benchmark + per-region diffs (re-archiving plots-full/ for both
# sides as a side effect of --replot) and immediately bundles the lot
# into one tarball. Same prerequisite as --replot itself: BASELINE and
# VERSION must already have completed runs under regression-runs/.
regression-report:
	@if [ -z "$(BASELINE)" ] || [ -z "$(VERSION)" ]; then \
		echo "error: regression-report needs both BASELINE and VERSION, e.g. make regression-report BASELINE=1.7.2 VERSION=1.7.3-rc" >&2; \
		exit 1; \
	fi
	./compare-scale-versions.sh --replot $(BASELINE) $(VERSION) \
		$(if $(BASELINE_LABEL),--baseline-label=$(BASELINE_LABEL)) \
		$(if $(CANDIDATE_LABEL),--candidate-label=$(CANDIDATE_LABEL))
	./compare-scale-versions.sh --archive $(BASELINE) $(VERSION) $(if $(ARCHIVE_OUT),--out=$(ARCHIVE_OUT))

help:
	@echo "make run                    -- one fleet sweep, default env (see run-regression-fleet.sh header)"
	@echo "make kill                   -- kill in-flight/orphaned fleet processes"
	@echo "make clean                  -- kill, then wipe the scratch workdir on every host"
	@echo "make ci VERSION=..          [MODE=native|version-diff|both] [BASELINE=..]"
	@echo "make ci-smoke VERSION=..    -- same as ci, forced to a fast tiny/1-iter/local-only run"
	@echo "make ci-release VERSION=.. BASELINE=.."
	@echo "make ci-local VERSION=.. EOD_REGRESSION_LOCAL_SCALE_BUILD=/path/to/build"
	@echo "                            -- conventional SCALE-vs-native heatmap, against a custom/local build"
	@echo "make archive-comparison BASELINE=.. VERSION=.."
	@echo "                            -- tar up both builds' full plot archives + diff heatmaps for handoff"
	@echo "make regression-report BASELINE=.. VERSION=.. [CANDIDATE_LABEL=..] [BASELINE_LABEL=..]"
	@echo "                            -- one-shot: replot both diffs, then tar up the lot for handoff"
	@echo "Any EOD_REGRESSION_* env var can be added to any of the above, e.g.:"
	@echo "    make ci MODE=version-diff VERSION=scale-master BASELINE=1.7.2 EOD_REGRESSION_SIZE=tiny"
	@echo "To run a regression check:"
	@echo "EOD_REGRESSION_REMOTE_TARGETS=\"trill\" make ci-release VERSION=1.7.3-rc BASELINE=1.7.2 EOD_REGRESSION_LOCAL_SCALE_BUILD=<path-to-nightly>"
	@echo "Where the nightly was generated by running "
	@echo "earth-to-scale <git commit>"
