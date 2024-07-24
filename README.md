# SCALE Validation

This repository contains the scripts we use to build/test [SCALE](https://docs.scale-lang.com/)

It also serves as a place to store github tickets for user-reported bugs in SCALE.

Some of the scripts in this repository are for projects that do not currently work
with SCALE. These are here to help facilitate testing, and to show how far we've gotten
with various things.

## Things that work

The current list of projects that are passing in our CI runs can be found [here](https://docs.scale-lang.com/#what-projects-have-been-tested)

Projects not listed there, but available here, have known issues.

Using a version of GCC >= 12, or the clang provided by SCALE, is recommended.

## Patches

A small number of projects have patches. These are documented in the scripts for the specific projects that have them. 

Typically, the patches are either:

- Fixing upstream bugs relating to gcc14 compatibility.
- Fixing upstream bugs due to newer dependency versions (we're using Arch over here).

These are patches that can be submitted upstream as valid bugfixes, rather than "things that will necessarily be needed to work with SCALE".

## How to run these scripts

The simplest way to run a test is to use the test driver script, `test.sh` (found in `thirdparty/` within this repository).

An example invocation is:

```
./test.sh ~/cuda_tests /opt/scale/targets/gfx1030 sm_86 xgboost
```

The arguments are, in order:

- A temporary directory to be used for the test. The same temporary directory can be used for many tests runs, and runs
  of different tests from this repo (the tests make subdirectories for themselves). This directory will contain the build
  artefacts and source code for the project under test.
- A path to a SCALE target directory.
- The build architecture to pass to the project's build system.
- The name of the project to test (must match a directory name under `thirdparty/` in this repo).

This script just runs the specific scripts found in `thirdparty/<name>` in lexicographical order with the same arguments
given.

### Test scripts

Each script in the project directories accepts the following optional arguments:

 - `-s`: Build sequentially.
 - `-v`: Verbose

The scripts return one of three exit codes:

 - 0: Success.
 - 1: Failure. No later script from the same directory can run.
 - 222: Failure. Later scripts from the same directory can still run.

### Script result file

Each script may create a result file in the test project's output directory. It will be named according to the script.
The output file is a CSV file. Each row consists of the following fields:

 - Row name. This describes the result.
 - Result type. The type of result. Options are:
   - `status`: The overall status of the test/subtest. Either `pass` or `fail`.
   - `count`: Count something. For example, number of failures.
   - `time`: The amount of time taken by something, in seconds.
   - `accuracy`: The accuracy (from 0.0 to 1.0) of a result.
   - `loss`: A measure of inaccuracy of a result (0 is perfect, larger numbers are worse).
 - Result value. A value of the given type.

This format is chosen for easy sequential emission, and easy parsing.

### Test directory paths

The first test script for a given test directory creates a subdirectory within the output directory for that test
project. Aside from these directories, the following paths in the output directory may be created:

 - `data`: This directory is used to cache datasets used by the tests. Test data is placed here when the test scripts
           that use it run. If the test data already exists, it is used without extra download. Since the test data may
           be very large, it's a good idea to make this a symlink to somewhere persistent.


### The `util` directory

This directory contains scripts used by the test scripts. See the individual scripts for information about what they do.

