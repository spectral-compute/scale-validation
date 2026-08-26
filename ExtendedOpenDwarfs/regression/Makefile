# Makefile for scale-validation/ExtendedOpenDwarfs/regression/.
#
# Thin wrapper around run-regression-fleet.sh / kill-regression-fleet.sh --
# all the actual configuration (which hosts, which SCALE version, app/size/
# iters, etc.) is still done via the env vars those two scripts already
# document in their own headers; this Makefile doesn't introduce a second,
# parallel configuration mechanism. Deliberately doesn't wrap
# compare-scale-versions.sh / run-regression-ci.sh here -- those take
# positional version arguments that don't fit a bare `make run` the same
# way, so invoke them directly for version-diff comparisons.
#
# Usage:
#   make run                                  # ./run-regression-fleet.sh with default env
#   EOD_REGRESSION_SCALE_VERSION=1.7.2 make run
#   make kill                                 # kill any in-flight/orphaned fleet processes, keep scratch dirs
#   make clean                                # kill, then also rm -rf the scratch workdir on every host
#
SHELL := /usr/bin/env bash
.PHONY: run kill clean

run:
	./run-regression-fleet.sh

kill:
	./kill-regression-fleet.sh

clean:
	EOD_REGRESSION_KILL_CLEAN=1 ./kill-regression-fleet.sh
