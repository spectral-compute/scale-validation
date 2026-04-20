# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE: master <4c2eee87>.**

Test scripts get added to this repository long before they are fully supported by SCALE, so some tests are expected to fail.
We use the outcome of this kind of testing to prioritise development.
Contributions welcome!

| Project        | Version                    | Status                   | Valid GFX                 |
|----------------|----------------------------|--------------------------|---------------------------|
| Alien          | scaletest       | ➖       | gfx1030: ✅, gfx1100: ✅, gfx90a: ✅, sm_89: ❌, gfx900: ❌, gfx1201: ❌       |
| AMGX           | v2.4.0        | ➖        | sm_89: ✅, gfx90a: ✅, gfx900: ✅, gfx1201: ✅, gfx1030: ❌, gfx1100: ❌        |
| arrayfire      | v3.9.0   | ➖   | sm_89: ✅, gfx90a: ✅, gfx900: ✅, gfx1201: ✅, gfx1030: ❌, gfx1100: ❌   |
| bitnet         | 404980eecae38a...      | ➖      | gfx1030: ✅, sm_89: ✅, gfx900: ✅, gfx90a: ❌, gfx1201: ❌, gfx1100: ❌      |
| caffe          | 9b891540183ddc...       | ➖       | gfx1030: ✅, gfx1201: ✅, gfx1100: ✅, sm_89: ✅, gfx900: ✅, gfx90a: ❌       |
| ctranslate2    | v4.5.0 | ➖ | gfx90a: ✅, gfx900: ✅, gfx1201: ✅, gfx1100: ✅, gfx1030: ❌, sm_89: ❌ |
| cuml           | b17f2db        | ➖        | gfx90a: ✅, gfx900: ✅, gfx1201: ✅, gfx1030: ❌, sm_89: ❌, gfx1100: ❌        |
| cuSZ           | v0.16.2        | ➖        | gfx1030: ✅, sm_89: ✅, gfx90a: ❌, gfx900: ❌, gfx1201: ❌, gfx1100: ❌        |
| CUTLASS        | v4.1.0     | ❓ (\*)     |      |
| CV-CUDA        | f769fe4     | ➖     | sm_89: ✅, gfx90a: ✅, gfx900: ✅, gfx1030: ❌, gfx1100: ❌, gfx1201: ❌     |
| cycles         | v4.4.0      | ➖      | gfx1030: ✅, sm_89: ✅, gfx90a: ❌, gfx900: ❌, gfx1201: ❌, gfx1100: ❌      |
| faiss          | v1.9.0       | ➖       | gfx90a: ✅, gfx900: ✅, gfx1201: ✅, gfx1100: ✅, gfx1030: ❌, sm_89: ❌       |
| FastEddy       | v2.0.0    | ➖    | gfx1100: ❌, gfx1030: ❌, gfx900: ✅, sm_89: ❌, gfx90a: ❌, gfx1201: ❌    |
| FLAMEGPU2      | v2.0.0-rc.2   | ➖   | gfx90a: ✅, gfx1201: ✅, sm_89: ❌, gfx900: ❌, gfx1030: ❌, gfx1100: ❌   |
| ggml           | d3a58b0        | ➖        | sm_89: ✅, gfx1030: ❌, gfx90a: ❌, gfx900: ❌, gfx1201: ❌, gfx1100: ❌        |
| gomc           | 4c12477        | ➖        | gfx1030: ✅, sm_89: ✅, gfx1100: ✅, gfx900: ✅, gfx90a: ❌, gfx1201: ❌        |
| gpu\_jpeg2k    | ee715e9  | ➖  | gfx900: ✅, gfx1201: ✅, gfx1100: ✅, gfx1030: ❌, sm_89: ❌, gfx90a: ❌  |
| GPUJPEG        | 3e045d1     | ❌     |      |
| GROMACS        | v2025.4     | ❓ (\*)     |      |
| hashcat        | 6716447dfce969...     | ➖     | gfx1030: ✅, sm_89: ✅, gfx90a: ❌, gfx900: ❌, gfx1201: ❌, gfx1100: ❌     |
| hashinator     | 34cf188  | ➖  | gfx90a: ✅, gfx900: ✅, gfx1030: ❌, sm_89: ❌, gfx1201: ❌, gfx1100: ❌  |
| HeCBench       | 42e8f09f3f7fa9...    | ➖    | sm_89: ✅, gfx90a: ✅, gfx1201: ✅, gfx1030: ❌, gfx1100: ❌, gfx900: ❌    |
| hypre          | v2.33.0       | ❌       |        |
| jitify         | master      | ➖      | gfx1030: ✅, sm_89: ❌, gfx900: ✅, gfx90a: ❌, gfx1100: ❌, gfx1201: ❌      |
| llama.cpp      |    | ❓ (\*)   |    |
| llm.c          | 7ecd8906afe6ed...       | ➖       | gfx90a: ✅, gfx900: ✅, gfx1201: ✅, gfx1100: ✅, gfx1030: ❌, sm_89: ❌       |
| MAGMA          | v2.9.0       | ➖       | gfx1030: ✅, gfx1201: ✅, gfx1100: ✅, sm_89: ✅, gfx90a: ✅, gfx900: ❌       |
| nvflip         | 1eb247c      | ➖      | gfx1030: ✅, sm_89: ❌, gfx90a: ❌, gfx900: ❌, gfx1201: ❌, gfx1100: ❌      |
| OpenCV         | 725e440      | ➖      | gfx90a: ✅, gfx900: ✅, gfx1201: ✅, gfx1100: ✅, gfx1030: ❌, sm_89: ❌      |
| openmpi        | v4.1     | ✅                       |                           |
| PhysX          | 1e44a0e       | ➖       | sm_89: ✅, gfx900: ✅, gfx1201: ✅, gfx1030: ❌, gfx1100: ❌, gfx90a: ❌       |
| pytorch        | v2.9.0-rc4     | ➖     | gfx90a: ✅, gfx900: ✅, gfx1201: ✅, gfx1030: ❌, sm_89: ❌, gfx1100: ❌     |
| quda           | 07822b61c6ab5f...        | ✅        |         |
| risc0          | v1.2.2       | ➖       | gfx90a: ✅, gfx1201: ✅, gfx1030: ❌, sm_89: ❌, gfx1100: ❌, gfx900: ❌       |
| rodinia\_suite |      | ❓ (\*)     |      |
| stdgpu         | 563dc59d6d08df...      | ➖      | gfx1030: ✅, sm_89: ✅, gfx90a: ❌, gfx900: ❌, gfx1201: ❌, gfx1100: ❌      |
| TCLB           | v6.7        | ➖        | gfx1030: ✅, gfx1100: ✅, sm_89: ❌, gfx90a: ❌, gfx900: ❌, gfx1201: ❌        |
| thrust         | 756c5af      | ➖      | gfx90a: ✅, gfx900: ✅, gfx1201: ✅, gfx1100: ✅, sm_89: ❌, gfx1030: ❌      |
| timemachine    | 01f14f8 | ➖ | gfx900: ✅, gfx1201: ✅, gfx1100: ✅, sm_89: ❌, gfx1030: ❌, gfx90a: ❌ |
| UppASD         | gpu_new      | ❌      |       |
| vllm           | v0.6.3        | ➖        | gfx90a: ✅, gfx1100: ✅, sm_89: ❌, gfx1030: ❌, gfx1201: ❌, gfx900: ❌        |
| whispercpp     |  | ❓ (\*) |  |
| xgboost        | v2.1.0     | ➖     | gfx900: ✅, gfx1201: ✅, gfx1100: ✅, sm_89: ❌, gfx1030: ❌, gfx90a: ❌     |

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
