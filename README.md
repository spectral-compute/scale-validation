# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE: master <06b011fd>.**

Test scripts get added to this repository long before they are fully supported by SCALE, so some tests are expected to fail.
We use the outcome of this kind of testing to prioritise development.
Contributions welcome!

| Project        | Version                    | gfx1100|
|----------------|----------------------------| -|
| alien          | v4.12.3       | ✅|
| arrayfire          | v3.10.0       | 🛠️️|
| bitnet          | 404980eecae38a...       | ✅|
| caffe          | 9b891540183ddc...       | ✅|
| ctranslate2          | v4.8.0       | 🛠️️|
| cuml          | b17f2db       | 🛠️️|
| cuSZ          | v0.17.3       | ✅|
| cycles          | v5.1.0       | ✅|
| FastEddy          | v5.0.0       | ✅|
| ffmpeg          | n8.1.2       | ✅|
| FLAMEGPU2          | v2.0.0-rc.4       | 🛠️️|
| GPUJPEG          | 3e045d1       | ✅|
| HeCBench          | 42e8f09f3f7fa9...       | ✅|
| PhysX          | 1e44a0e       | 🛠️️|
| RabbitCT          | 1f1359afad1355...       | ✅|
| TCLB          | v6.7       | ✅|
| UppASD          | gpu_new       | ✅|

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ❓ Validation skipped
* 🛠️️ Tested, but not expected to pass

Pipeline ID: 13912.

## Running Tests

Each directory (except `util`) contains a set of scripts that should be executed
in lexicographical order for a complete test. These scripts are mostly just
the normal CUDA build instructions for the corresponding project.

Note that you may need to install the system dependencies described on the project
website before this will succeed.

The test driver script `test.sh` may be used to conveniently execute an
entire test:

```bash
./test.sh <workdir> <path_to_scale> gfx1234 <name_of_test>
```

For example: `./test.sh ~/cuda_tests /opt/scale gfx1100 hashcat`.

See the `test.sh` usage message for more detailed information and other
options for adjusting how tests are run.

### The `util` directory

This directory contains scripts used by the test scripts. See the individual
scripts for information about what they do.