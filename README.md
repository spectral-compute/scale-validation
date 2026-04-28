# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE: v1.6.1.**

Test scripts get added to this repository long before they are fully supported by SCALE, so some tests are expected to fail.
We use the outcome of this kind of testing to prioritise development.
Contributions welcome!

| Project        | Version           | Status | Valid GFX                                                     |
|----------------|-------------------|--------|---------------------------------------------------------------|
| Alien          | scaletest         | ✅     |                                                               |
| AMGX           | v2.4.0            | ❌     |                                                               |
| arrayfire      | v3.9.0            | ❌     |                                                               |
| bitnet         | 404980eecae38a... | ✅     |                                                               |
| caffe          | 9b891540183ddc... | ✅     |                                                               |
| ctranslate2    | v4.5.0            | ✅     |                                                               |
| cuml           | b17f2db           | ❌     |                                                               |
| cuSZ           | v0.16.2           | ✅     |                                                               |
| CUTLASS        | v4.1.0            | ✅     |                                                               |
| CV-CUDA        | f769fe4           | ❌     |                                                               |
| cycles         | v4.4.0            | ✅     |                                                               |
| faiss          | v1.9.0            | ❌     |                                                               |
| FastEddy       | v2.0.0            | ✅     |                                                               |
| FLAMEGPU2      | v2.0.0-rc.2       | ➖     | gfx1030: ✅, gfx1201: ❌, gfx1100: ❌, gfx90a: ❌             |
| ggml           | d3a58b0           | ➖     | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅, gfx90a: ❌ |
| gomc           | 4c12477           | ✅     |                                                               |
| gpu\_jpeg2k    | ee715e9           | ❌     |                                                               |
| GPUJPEG        | 3e045d1           | ✅     |                                                               |
| GROMACS        | v2025.4           | ✅     |                                                               |
| hashcat        | 6716447dfce969... | ✅     |                                                               |
| hashinator     | 34cf188           | ❌     |                                                               |
| HeCBench       | 42e8f09f3f7fa9... | ❌     |                                                               |
| hypre          | v2.33.0           | ❌     |                                                               |
| jitify         | master            | ➖     | gfx1100: ✅, gfx1030: ✅, gfx90a: ✅, gfx1201: ❌             |
| llama.cpp      |                   | ➖     | gfx1100: ✅, gfx1030: ❌, gfx90a: ❌, gfx1201: ✅,            |
| llm.c          | 7ecd8906afe6ed... | ❌     |                                                               |
| MAGMA          | v2.9.0            | ❌     |                                                               |
| nvflip         | 1eb247c           | ✅     |                                                               |
| OpenCV         | 725e440           | ❌     |                                                               |
| openmpi        | v4.1              | ✅     |                                                               |
| PhysX          | 1e44a0e           | ❌     |                                                               |
| pytorch        | v2.9.0-rc4        | ❌     |                                                               |
| quda           | 07822b61c6ab5f... | ❌     |                                                               |
| risc0          | v1.2.2            | ❌     |                                                               |
| rodinia\_suite |                   | ✅     |                                                               |
| stdgpu         | 563dc59d6d08df... | ✅     |                                                               |
| TCLB           | v6.7              | ✅     |                                                               |
| thrust         | 756c5af           | ❌     |                                                               |
| timemachine    | 01f14f8           | ❌     |                                                               |
| UppASD         | gpu_new           | ✅     |                                                               |
| vllm           | v0.6.3            | ❌     |                                                               |
| whispercpp     |                   | ➖     | gfx1100: ✅, gfx1030: ✅, gfx90a: ❌, gfx1201: ✅             |
| xgboost        | v2.1.0            | ❌     |                                                               |

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ➖ Conflicting statuses, see notes for different architectures
* ✅ (\*) Validation skipped, last known status was Valid
* ❌ (\*) Validation skipped, last known status was Invalid
* ❓ (\*) Validation skipped, no previous validation state to reference

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
