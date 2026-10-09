# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo holds scripts that clone, build, and test ~50 open-source CUDA projects to
validate the correctness of [SCALE](https://docs.scale-lang.com/) (a toolkit that
compiles CUDA code for NVIDIA and AMD GPUs). Each top-level directory (e.g. `hashcat/`,
`llama.cpp/`, `gromacs/`) is one project under test. Many tests are added before SCALE
fully supports the project, so failures are expected and used to prioritise development.

## Auditing freshness of tested projects

The projects under test are upstream open-source projects this suite validates SCALE
against — not dependencies of this repo. To check how far behind upstream each tested
project's pinned ref is, use the `upstream-staleness` skill
(`.claude/skills/upstream-staleness/SKILL.md`) — it iterates `versions.txt`, queries each
upstream via `git ls-remote`, and reports the release gap.

## Running a test

```bash
./test.sh <workdir> <path_to_toolkit> <gpu_arch> <test_name>
# e.g. ./test.sh ~/cuda_tests /opt/scale gfx1100 hashcat
```

`test.sh` is the driver. It wipes `<workdir>/<test_name>`, sets up the toolchain
environment, then runs every `*.sh` in the test directory **in lexicographical order**
with `set -o errexit` — the first failing script fails the test.

### Toolchain selection

`<path_to_toolkit>` is either a SCALE install or an NVIDIA CUDA install, identified from
its layout:

- `bin/scaleenv` present → **SCALE**. `test.sh` sources `<toolkit>/bin/scaleenv
  <gpu_arch>`, which sets up the CUDA environment (`CUDAARCHS`, `PATH`, `SCALE_ENV`, ...)
  for the target, AMD (`gfx*`) or NVIDIA (`sm_*`). The colour-diagnostic flags and the
  long `NVCC_APPEND_FLAGS` list of `-Wno-*` warning suppressions that go with it are
  exported by `util/prelude.sh`, only when `SCALE_ENV` is set, so they never reach
  NVIDIA's `nvcc` (`test.sh` and `benchmark.py` unset `SCALE_ENV` on non-SCALE paths).
- otherwise `bin/nvcc` present → **NVIDIA CUDA**. `test.sh` exports the variables
  `scaleenv` would have set (`CUDA_PATH`, `CUDACXX`, `CUDAARCHS` with the `sm_` prefix
  stripped, `PATH`, `LD_LIBRARY_PATH`, ...).
- neither → error.

The order matters: a SCALE install also ships a `bin/nvcc`.

`test.sh` exports `TEST_GPU_ARCH` (the raw `<gpu_arch>` argument) for per-project
scripts. It records the mode (`scale` or `nvidia-cuda`) in the log header, but
**doesn't export it**. A script that needs to know whether it's running under SCALE
checks `[[ -n "${SCALE_ENV:-}" ]]` (see `HeCBench/01-build.sh`).

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

## Running a benchmark

```bash
./benchmark.py <workdir> <path_to_toolkit> <gpu_arch> <project> [options]
# e.g. ./benchmark.py ~/cuda_tests /opt/scale gfx1100 HeCBench -n 5 -d 0
#      ./benchmark.py ~/cuda_tests /opt/rocm  gfx1100 HeCBench --dry-run
```

`benchmark.py` is the benchmarking counterpart to `test.sh`, for comparing performance
of the same project across toolchains: SCALE, NVIDIA CUDA, and native ROCm/HIP. It only
works with projects that have a `benchmarks/` subdirectory. Neither `test.sh` nor CI looks inside `benchmarks/`.

### Toolchain selection

The toolchain is a `Compiler` enum (`scale`, `nvcc`, `hip`). It's detected from the
toolkit layout the same way `test.sh` does it, plus HIP: `bin/scaleenv` → `scale`, else
`bin/nvcc` → `nvcc`, else `bin/hipcc`/`bin/hipconfig` → `hip`. `-c/--compiler` overrides
detection. Environment set up for each:

- `scale`: sources `scaleenv <gpu_arch>`. The colour and `-Wno-*` flags come from
  `util/prelude.sh` as usual (see "Toolchain selection" above).
- `nvcc`: the same `CUDA_*`/`PATH`/`LD_LIBRARY_PATH`/`CUDAARCHS` variables as
  `test.sh`'s NVIDIA branch, with `SCALE_ENV` dropped.
- `hip`: `ROCM_PATH`/`ROCM_HOME`/`HIP_PATH`, `HIPARCHS=<gpu_arch>`, `HIPCXX` (the
  toolkit's `llvm/bin/clang++` if present), plus `PATH`, `LD_LIBRARY_PATH` (`lib`) and
  `CMAKE_PREFIX_PATH`. `CUDAARCHS` is **not** set, so HIP scripts use `$TEST_GPU_ARCH`.

Every script also gets `MAKEFLAGS="-O -k"`, `TEST_GPU_ARCH`, and:

- `BENCHMARK_COMPILER`: `scale`, `nvcc` or `hip`.
- `BENCHMARK_REPEATS` / `BENCHMARK_REPEAT`: total runs (`-n`), and the 1-based index of
  the current run.
- `RESULTS_DIR`: where scripts should write result files (`--results-dir`, default
  `<workdir>/results`, created for you). It sits beside the per-project workdir, so it
  survives the wipe.
- `CUDA_VISIBLE_DEVICES` (or `HIP_VISIBLE_DEVICES` for `hip`), only if `-d/--device` is
  given. It's repeatable or comma-separated. Optional but recommended as if
  there's an issue running scripts it's usually because you need to be explicit about the devices to run on (particularly on heterogeneous systems).

### Script selection

Scripts are gathered from both `<project>/` and `<project>/benchmarks/`. Each is keyed
on its filename with any trailing toolchain suffix stripped: `-scale`, `-nvcc`, `-cuda`
or `-hip` (so `02-benchmark-cuda.sh` and `02-benchmark-hip.sh` both have key
`02-benchmark`). For each key, one script runs:

1. A script in `benchmarks/` beats one in the project's base folder.
2. Within a folder, the most specific suffix the toolchain accepts wins:
   `scale` → `-scale`, then `-cuda`; `nvcc` → `-nvcc`, then `-cuda`; `hip` → `-hip`.
   An unsuffixed script ranks last and runs for every toolchain. A script suffixed for
   a different toolchain is ignored.

The winners run in lexicographic order of key, stopping at the first failure. By
default, scripts with `test` in their name are skipped unless they also contain
`benchmark` (`--include-tests` runs them too). Scripts with `benchmark` in their name run
`-n` times; everything else (clone, build) runs once. `--dry-run` prints the resolved
list. For example, HeCBench under `scale`/`nvcc` runs `00-clone.sh`, `01-build.sh` and
`benchmarks/02-benchmark-cuda.sh`; under `hip` it swaps in `benchmarks/01-build-hip.sh`
and `benchmarks/02-benchmark-hip.sh`.

### Adding benchmarks to a project

- Put benchmark-only and toolchain-specific scripts in `<project>/benchmarks/`. **Never
  put suffixed variants (`-hip.sh` etc.) in the project base folder.** `test.sh` runs
  every `*.sh` there regardless of suffix, so a HIP script would run under SCALE/CUDA
  test runs and in CI.
- Reuse the base folder's clone/build scripts wherever they already work for the
  toolchain. Only override a key in `benchmarks/` when a toolchain needs something
  different, e.g. `HeCBench/benchmarks/01-build-hip.sh`.
- Match keys across the base folder and `benchmarks/` exactly (same number and stem),
  or the override won't replace the base script and both will run.
- Scripts in `benchmarks/` are one directory deeper. Source the prelude as
  `. "$(dirname "$0")"/../../util/prelude.sh`, with a `# shellcheck
  source-path=SCRIPTDIR` line above it (copy the header from an existing one).
- Write results under `$RESULTS_DIR`, with toolchain and arch in the filename (e.g.
  HeCBench's `hecbench.<mode>.<arch>.<timestamp>.csv`). Keep the names unique per
  repeat, so `-n` runs don't overwrite each other. Fall back to a default
  (`${RESULTS_DIR:-...}`) if the same script is also run by `test.sh`.
- A benchmark script should still exit non-zero when it produces nothing usable (e.g.
  HeCBench fails if the CSV has only a header). Otherwise a broken build shows up as a
  "passing" benchmark.

### Logs

Each run writes `<workdir>/logs/<project>-benchmark-<YYYYMMDDHHMMSSZ>.log`, alongside
`test.sh`'s logs: a header (project, compiler, toolkit, arch, devices, repeats), every
script's output with `--- Executing ... ---` banners (repeats labelled `[i/n]`), then
an `=== RESULTS ===` table with `SCRIPT`/`STATUS`/`DETAIL` columns and a final
`ALL SCRIPTS PASSED` / `FAILED:` line. Unlike `test.sh`'s table, there's no `KIND`
column and `util/checks.sh` `CHECK` rows aren't collected. Exit status is the failing
script's exit code, or 0.[^benchmark-collation]

[^benchmark-collation]: This log and per-run `$RESULTS_DIR` layout is temporary. Each
    run's results currently stand alone. Collating data from across runs and analysing it
    is a planned future step, so don't build tooling that depends on the current layout.

## Authoring / editing a test

A test directory is a sequence of numbered scripts run in order:

```
00-clone.sh   01-build.sh   02-test-*.sh   03-benchmark-*.sh
```

Each script starts by sourcing `util/prelude.sh` — `. "$(dirname "$0")"/../util/prelude.sh`
— instead of hand-rolling a shebang/`set -e`. It sets `set -ETeuo pipefail` (plus `set -x`
tracing when `SPECTRAL_TRACE=1`), exports `SCALE_VALIDATION` (repo root) and `SCRIPT_DIR`,
defines a `log()` helper (echoes to stderr), and sources `util/git.sh` for you. Conventions:

- **Clone** via the `util/git.sh` helpers `prelude.sh` already sourced: `do_clone <dir>
  <url> <ref>`. `do_clone` auto-detects whether `<ref>` is a branch/tag (shallow clone) or
  a full commit hash (full clone + checkout), so `do_clone_hash` is now just a legacy
  alias for `do_clone` — prefer `do_clone` in new scripts. Pin the ref with
  `get_version <name>`, which reads `$SCALE_VALIDATION/versions.txt`.
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

## What CI runs, and expected failures

CI decides what to build/run per project via `util/gen_matrix.py` (see
`README_INTERNAL.md` for the full internal-only details, including a one-liner to debug
the generated matrix locally). Marker files at the top of a project directory tell it
what to expect — presence is all that matters, contents are ignored:

- `.skip-ci` — don't build or run this project in CI at all.
- `.build-only` — build it, but there's nothing useful to run afterwards.
- `.build-fails` / `.run-fails` — building or running is expected to fail (xfail) on
  every ISA.
- `.build-fails-on-$ISA` / `.run-fails-on-$ISA` (e.g. `.build-fails-on-gfx1100`) — same,
  but scoped to one specific GPU arch.

`.dependencies` is different: its contents matter. It lists the system packages a
project needs beyond the `scale-test-<distro>` image. These files are the start of a
move from the shared `scale-ci-*` images to one image per project. See `README.md` for
the line format.

## README status table

The status table in `README.md` (per-project ✅/❌/❓ across GPU archs) is regenerated by
automated CI runs (see the `chore: Automated update of README` commits) — don't
edit this table at all.

## Shell style and pre-commit hooks

`.pre-commit-config.yaml` runs `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`,
`check-added-large-files`, `shellcheck`, and `shfmt -w` on every commit. `.shellcheckrc`
sets `shell=bash`, disables `SC1091` (can't-follow-source), and points
`source-path=SCRIPTDIR/../util/` so shellcheck can resolve the `util/*.sh` sources every
test script pulls in. `.editorconfig` fixes shell scripts at 4-space indentation
(`shfmt` formats to match). `.dir-locals.el.example` is a template for Emacs users who
want `shfmt` wired up as a `format-all-mode` formatter — copy it to `.dir-locals.el`
(gitignored) to use it.
