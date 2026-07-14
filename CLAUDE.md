# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo holds scripts that clone, build, and test ~50 open-source CUDA projects to
validate the correctness of [SCALE](https://docs.scale-lang.com/) (a toolkit that
compiles CUDA code for NVIDIA and AMD GPUs). Each top-level directory (e.g. `hashcat/`,
`llama.cpp/`, `gromacs/`) is one project under test. Many tests are added before SCALE
fully supports the project, so failures are expected and used to prioritise development.

## Running a test

```bash
./test.sh <workdir> <path_to_scale> <gpu_arch> <test_name>
# e.g. ./test.sh ~/cuda_tests /opt/scale gfx1100 hashcat
```

`test.sh` is the driver. It wipes `<workdir>/<test_name>`, sources SCALE's environment
(`<scale>/bin/scaleenv <gpu_arch>`), then runs every `*.sh` in the test directory **in
lexicographical order** with `set -o errexit` — the first failing script fails the test.

- `<path_to_scale>` may point at a real SCALE install **or** at an NVIDIA CUDA install.
  If `bin/scaleenv` exists it's treated as SCALE; otherwise `test.sh`/`args.sh`
  replicate the CUDA environment variables `scaleenv` would set so the same scripts run
  unmodified against stock `nvcc`. This dual-mode behavior is intentional.
- GPU arch is AMD-style (`gfx1100`, `gfx90a`) for SCALE or `sm_120` for NVIDIA.

Two optional flags, appended after `<test_name>`, support running against an
already-built project (used by the container test stage below) without changing
default native behavior:

- `--match <regex>`: only run scripts whose filename matches the regex, instead of
  every `*.sh`. The test/benchmark naming convention (see "Authoring / editing a
  test" below) means `--match '-(test|benchmark)'` runs just those.
- `--keep`: don't wipe `<workdir>/<test_name>` first; just run against whatever's
  already there (still creates the directory if it's missing).

## Logs and results

Every `./test.sh` run writes one durable log file to `<workdir>/logs/` — one level above
the per-test workdir, so it's shared across every project tested against that `WORKDIR`
and survives the `rm -rf <workdir>/<test_name>` wipe at the top of each run. Nothing is
ever overwritten: each invocation gets its own file,
`<test_name>-<YYYYMMDDHHMMSSZ>.log` (UTC timestamp), so history accumulates across runs
and projects in one place.

Each file contains, in order:
- The full chronological stdout+stderr of every script in the sequence, in execution
  order, with the `--- Executing ... ---` banners, a small header (test name, gpu arch,
  scale dir, mode, start time), and a final `ALL SCRIPTS PASSED` / `FAILED: ...` line.
  Console output still streams live as normal; this is a copy, not a replacement.
- A single `=== RESULTS ===` table at the bottom, fixed-width `KIND`/`SCRIPT`/`STATUS`
  columns (easy to `grep`/`awk`) followed by a freeform `DETAIL` column (easy to read).
  One `SCRIPT` row per script that ran (`exit=<code> duration=<seconds>s`), immediately
  followed by any `CHECK` rows it recorded via `util/checks.sh` (see "Multi-check files"
  below) — e.g.:
  ```
  KIND    SCRIPT                                      STATUS  DETAIL
  SCRIPT  05-test-hash-modes.sh                        FAIL    exit=1 duration=8s
  CHECK   05-test-hash-modes.sh                        PASS    crack MD5
  CHECK   05-test-hash-modes.sh                        FAIL    dictionary attack (-a 0, build/example.dict)
  ```
  A script with no checks just has its `SCRIPT` row, no `CHECK` rows beneath it — that's
  expected, not an error.

This table is appended at the very end regardless of how the run finishes — success, a
failing script, or an unexpected error — via a `trap ... EXIT` in `test.sh`, so the
useful debugging context is always there even when a run aborts partway through.

To hand a run's results to someone else for debugging without them needing to re-run
anything: just point them at (or attach) that one `.log` file.

## Authoring / editing a test

A test directory is a sequence of numbered scripts run in order:

```
00-clone.sh   01-build.sh   02-test-*.sh   03-benchmark-*.sh
```

Each script is standalone (`#!/bin/bash` + `set -e`, often `set -ETeuo pipefail`) and
relies on the environment exported by the driver. Conventions:

- **Clone** via `util/git.sh` helpers — `source "$(dirname "$0")"/../util/git.sh`, then
  `do_clone <dir> <url> <ref>` (shallow, branch/tag) or `do_clone_hash` (full clone,
  arbitrary commit). Pin the ref with `get_version <name>`, which reads `versions.txt`.
- **`versions.txt`** is the single source of truth for which ref of each project is
  tested — update it here, never hardcode refs in scripts.
- **Build** out-of-source; use `${CUDAARCHS}` for the arch and `nvcc` as the CUDA
  compiler. The driver sets `MAKEFLAGS="-O -k"` to keep parallel build logs readable and
  build as much as possible (more signal on what's unsupported).
- Tests must exit non-zero on failure; correctness tests compare actual vs. expected
  output (see `hashcat/02-test-short.sh`).
- **Multi-check files**: when a file verifies several related but independent claims
  (e.g. multiple documented capabilities of one built binary), source `util/checks.sh`
  and use `check "<label>" <fn>` for each one instead of plain `set -e`. This runs every
  check even if earlier ones fail, and calls `check_exit` at the end to fail the script
  only once, after every check has had a chance to report — so one broken claim doesn't
  hide the pass/fail status of the others in the same file. Single-assertion files (e.g.
  `hashcat/02-test-short.sh`) don't need this — it's for files with more than one
  independent check (see e.g. `hashcat/05-test-hash-modes.sh`).
- **Image fidelity checks**: a `psnr_ppm <ref> <dec> [<threshold_db>]` bash function
  (PPM/PGM round-trip PSNR via an embedded Python snippet) is defined inline in
  `GPUJPEG/04-test-claims.sh`, rather than shared from `util/` — kept in the file so it
  stays self-contained, matching the MSE-via-ImageMagick-`compare` pattern already
  duplicated inline in `cycles/03-test-examples.sh` and `nvflip/02-test.sh`.

`util/args.sh` is a richer alternative arg-parser some tests source directly (supports
`SKIP_N`/`STOP_AFTER_N` phase selection, `-check` to validate ordering, and
`PARTIAL_PARSE`). It duplicates the `do_clone*`/`get_version` helpers from `git.sh`; keep
the two in sync if you change them.

The `00-clone`/`01-patch`/`0N-build` vs. `0N+1-test*`/`0N+2-benchmark*` naming convention
above isn't just cosmetic — it's what the container test stage (below) matches on to
find test scripts, so every new test/benchmark script must have `test` or `benchmark`
somewhere in its filename, and setup scripts must not.

## Container test stage

Projects with a `Dockerfile` (all but `GPUJPEG`, which isn't containerized yet) have a
`test` stage in addition to the usual `build` and (unnamed, final) runtime stages:

```bash
docker build --target test -t <project>:test --build-arg GPU_ARCH=gfx1100 -f <project>/Dockerfile .
docker run --rm --device /dev/dri --device /dev/kfd <project>:test
```

The `test` stage is `FROM build`, so it starts from the already-cloned-and-built project
with no extra work, then runs `test.sh` against that same directory with `--match
'-(test|benchmark)' --keep` baked into its `ENTRYPOINT` (see "Running a test" above for
what those flags do). Exit code is the only signal — 0 if every matched script passed,
nonzero otherwise. GPU device access only exists at `docker run` time, not `docker
build` time, which is why the tests run as the container's entrypoint rather than a
`RUN` step during the build. If a test/benchmark script needs a package the `build`
stage doesn't already install (e.g. `imagemagick`/`python3` for the CPU-vs-GPU parity
checks in `cycles`/`nvflip`), add it to the `test` stage directly, same as `cycles/Dockerfile`
and `nvflip/Dockerfile` do — don't rely on the runtime stage's packages, which the `test`
stage doesn't inherit (it's `FROM build`, not `FROM` the runtime stage).

## README status table

The status table in `README.md` (per-project ✅/❌/❓ across GPU archs) is regenerated by
automated CI runs (see the `chore: Automated update of README` commits) — don't
edit this table at all.
