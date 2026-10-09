---
name: verify-dependencies
description: Verify and complete one thirdparty project's `.dependencies` file for one distro by building the project in a scale-test container, installing whatever the build turns out to be missing, and recording it. Use when asked to verify, check, fix or fill in a project's `.dependencies`, or to find which system packages a project needs to build.
---

# Verify a project's `.dependencies`

Build ONE project in a clean `scale-test-<distro>` container. When the build fails
because something is missing, install it in the container, add it to the project's
`.dependencies`, and build again. Stop when the build stage passes. Never run the tests.

Arguments: the project directory name (e.g. `faiss`), the SCALE commit SHA whose nightly
package to build with, and optionally a distro (default `ubuntu24.04`, the only one
supported so far). If no SHA is given, ask for one.

Everything below has already been worked out. Do not re-investigate it.

## Helper

All docker work goes through `.claude/skills/verify-dependencies/verify.sh` (called
`verify.sh` below). Run it from `test/thirdparty`. Its header documents every command.

- `verify.sh setup P SHA`: starts container `verify-deps-<p>-ubuntu24.04` from a cached
  image that has SCALE installed, then installs the entries already in `P/.dependencies`.
  The first run in a sandbox pulls the base image (about 30 s) and installs SCALE.
- `verify.sh build P`: wipes the workdir, runs the build stage exactly as CI does, and
  prints the exit code. On failure it also prints the likely errors and the last lines.
  Builds can take from minutes to hours. Run it with `run_in_background` and wait for
  the notification. Do not poll it.
- `verify.sh errors P`: prints the likely-error lines from the last log again.
- `verify.sh install P apt:foo pip:bar ...`: installs entries into the container. It
  does not edit `.dependencies`.
- `verify.sh whichpkg <path>`: shows which apt packages provide a file, using apt-file in
  a separate throwaway container, so the build container stays clean. Pass the most
  specific path you have, e.g. `include/netcdf.h`, `bin/g++` or `libfoo.so`.
- `verify.sh cleanup P`: removes the container. Always run it at the end.

Settled facts the helper relies on:
- The registry `docker-registry:53454` is http-only and dockerd refuses it, so the helper
  pulls with `crane --insecure` and runs `docker load`.
- SCALE comes from the artefacts server (`packages/nightlies/<sha>/<distro>/`), the
  same as CI.
- If `setup` reports a 403 "Blocked by local rule for artefacts-dl.spectral.vpn", the
  sandbox blocks the artefacts
  server. Stop and tell the user to run this on their host:
  `sbx policy rm network --resource artefacts-dl.spectral.vpn`.
- The build runs `scripts/thirdparty-tests.sh` with `THIRDPARTY_TEST_ACTION=build`. That
  runs the project's scripts up to and including its last `*-build*` script, with the
  same environment as CI. Every project has a `*-build*` script, so no tests run.
- For FastEddy, hypre, AMGX and lammps, that script first builds the `openmpi` project.
  Packages that openmpi needs go in the original project's `.dependencies`.
- The build scripts cannot be rerun in place (e.g. they run `mkdir build`), so each
  `build` starts from a fresh clone. Batch fixes to keep the number of builds down.
- The repo is mounted read-only at `/src` in the container. Edit `.dependencies` on the
  host.
- No GPU is needed to build. Builds target `gfx1100`; set `GPU_ARCH` to change it.

## What `scale-test-ubuntu24.04` already has

These need no entry: clang, gcc, libstdc++-12-dev, libc-dev, make, cmake 4.0.3, ninja,
pkg-config, python3, git, wget, curl, tar, unzip, patch, rsync, jq, sudo.

These are NOT in it, and builds often need them: `g++` (C++ host compiler for gcc-based
builds and for nvcc), `python3-pip` (needed by `pip3`), `python3-venv`, `xz-utils`,
`file`, `bzip2`, `autoconf`/`automake`/`libtool`, `gfortran`, any `-dev` library.

## Loop

1. `verify.sh setup P SHA`. If an `ext:` entry fails with "Unrecognised ext spec", stop and
   report it: `images/install-ext.sh` does not handle that spec yet.
2. `verify.sh build P`. Exit code 0 means done: go to step 6.
3. Classify the failure from the printed lines. If they are not enough, `grep -n` the log
   for one specific string and print a few lines of context. Never print the whole log.
   - Missing dependency: go to step 4.
   - Anything else is not this skill's job. That covers SCALE compiler errors or crashes,
     CUDA API errors, a failed clone or download, timeouts, and patch failures. Stop and
     report it, quoting the shortest line that decides it.
4. Map each missing item to a package, using the table below first and
   `verify.sh whichpkg` second. Collect every missing item you can see in this log
   before rebuilding. `make -k` keeps going, so one log often shows several.
5. `verify.sh install P <entries>`, then add the same entries to `P/.dependencies`, then
   go to step 2. If the install fails, the package name is wrong; fix the name.
   - Give up after 10 builds and report what is still failing.
6. `verify.sh cleanup P` and report.

## Error to package

| Log line | Entry |
|---|---|
| `CMAKE_CXX_COMPILER` not found, `g++: not found`, nvcc host compiler not found | `apt:g++` |
| `fatal error: foo.h: No such file or directory` | `whichpkg include/foo.h`, pick the `-dev` package |
| `cannot find -lfoo` | `whichpkg libfoo.so`, pick the `-dev` package |
| CMake `Could NOT find Foo`, or no `FooConfig.cmake` | `whichpkg FooConfig.cmake` or `foo-config.cmake`, else `libfoo-dev` |
| pkg-config `No package 'foo' found` | `whichpkg foo.pc` |
| `foo: command not found`, or `Program foo not found` | `whichpkg bin/foo` |
| `No module named 'foo'` | `apt:python3-foo` if it exists (check with `whichpkg`), else `pip:foo` plus `apt:python3-pip` |
| `pip3: command not found` | `apt:python3-pip` |
| `ensurepip is not available` / venv failure | `apt:python3-venv` |
| `autoreconf`/`aclocal`/`libtoolize` not found | `apt:autoconf`, `apt:automake`, `apt:libtool` |
| BLAS/LAPACK not found | `apt:libopenblas-dev` |
| Boost component not found | `apt:libboost-<component>-dev` |
| `gfortran` / Fortran compiler not found | `apt:gfortran` |
| `xz: Cannot exec` / tar xz failure | `apt:xz-utils` |
| `bzip2: Cannot exec` | `apt:bzip2` |
| `meson: command not found` | `apt:meson` and `apt:ninja-build` |
| `swig` not found | `apt:swig` |
| `cargo`/`rustc` not found | stop and report: needs an `ext:` entry, which needs a decision |

Prefer the most specific package. Never add a metapackage such as `build-essential`.
If a missing item is only optional (CMake prints "not found" but carries on), do not add
it unless a later step fails because of it.

## `.dependencies` rules

- One line per package, `ubuntu24.04:<source>:<package>`, sorted, ending in a newline.
  The format is in `test/thirdparty/README.md`.
- List only packages that are not already in the base image (above), and only top-level
  packages, not what apt pulls in with them.
- Sources: `apt` first. Use `pip` only when there is no `python3-<module>` apt package.
  Use `pipx` only for command-line tools; `apt:pipx` must be listed too. Never add `ext`
  yourself.
- Do not remove existing entries. If one looks unnecessary, say so in the report.
- Only edit `P/.dependencies`. Never edit build scripts, patches or the helper.
- Never push, tag for a registry, or otherwise upload any docker image, to
  `docker-registry:53454` or anywhere else. All images stay local to this sandbox. Do
  not run `docker push`, `crane push`/`copy`/`append`, or `docker login`.

## Report

A few lines:
- Result: `built`, `stopped: <reason>`, or `gave up`.
- Entries added, each with the log line that showed it was needed.
- Existing entries that look unnecessary, if any.
- For a stop: the decisive log line and the log path.
