# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE: master <701c8950>.**

Test scripts get added to this repository long before they are fully supported by SCALE, so some tests are expected to fail.
We use the outcome of this kind of testing to prioritise development.
Contributions welcome!

| Project        | Version                    | gfx1100|
|----------------|----------------------------| -|
| alien          | v4.12.3       | ❌|
| AMGX          | v2.5.0       | 🛠️️|
| arrayfire          | v3.10.0       | 🛠️️|
| bitnet          | 404980eecae38a...       | ✅|
| caffe          | 9b891540183ddc...       | ✅|
| ctranslate2          | v4.8.0       | 🛠️️|
| cuml          | b17f2db       | 🛠️️|
| cuSZ          | v0.17.3       | ❌|
| cutlass          | v4.5.2       | ❌|
| CV-CUDA          | f769fe4       | 🛠️️|
| cycles          | v5.1.0       | ❌|
| faiss          | v1.14.3       | 🛠️️|
| FastEddy          | v5.0.0       | ❌|
| ffmpeg          | n8.1.2       | ❌|
| FLAMEGPU2          | v2.0.0-rc.4       | 🛠️️|
| ggml          | d3a58b0       | ✅|
| gomc          | 4c12477       | ❌|
| gpu_jpeg2k          | ee715e9       | 🛠️️|
| GPUJPEG          | 3e045d1       | ✅|
| gromacs          | v2025.4       | ❌|
| hashcat          | 6716447dfce969...       | ✅|
| hashinator          | 34cf188       | 🛠️️|
| HeCBench          | 42e8f09f3f7fa9...       | ✅|
| hypre          | v3.1.0       | 🛠️️|
| jitify          | master       | ❌|
| kokkos          |        | 🛠️️|
| llama.cpp          | b9680       | ❌|
| llm.c          | 7ecd8906afe6ed...       | 🛠️️|
| nixl          | e128059af332df...       | 🛠️️|
| nvflip          | 1eb247c       | ✅|
| opencv          | 725e440       | 🛠️️|
| PhysX          | 1e44a0e       | 🛠️️|
| pytorch          | v2.12.1       | 🛠️️|
| quda          | 07822b61c6ab5f...       | 🛠️️|
| RabbitCT          | main       | ✅|
| risc0          | v3.0.5       | 🛠️️|
| rodinia_suite          | spectral       | ✅|
| stdgpu          | 563dc59d6d08df...       | ❌|
| TCLB          | v6.7       | ✅|
| thrust          | 756c5af       | 🛠️️|
| timemachine          | 01f14f8       | 🛠️️|
| UppASD          | gpu_new       | ✅|
| vllm          | v0.24.0       | 🛠️️|
| warp          | v1.14.0       | 🛠️️|
| whispercpp          | v1.9.0       | ❌|
| xgboost          | v3.3.0       | 🛠️️|

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ❓ Validation skipped
* 🛠️️ Tested, but not expected to pass

Pipeline ID: 14215.

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