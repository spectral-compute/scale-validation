# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE: master <9c2d4543>.**

Test scripts get added to this repository long before they are fully supported by SCALE, so some tests are expected to fail.
We use the outcome of this kind of testing to prioritise development.
Contributions welcome!

| Project        | Version                    | gfx90a|gfx1201|gfx1100|linux|
|----------------|----------------------------| -|-|-|-|
| alien          | v4.12.3       | ✅|✅|✅|❓|
| AMGX          | v2.4.0       | ❌️️|❌️️|❌️️|❓|
| arrayfire          | v3.9.0       | ❌️️|❌️️|❌️️|❓|
| bitnet          | 404980eecae38a...       | ❓|❓|❓|❓|
| caffe          | 9b891540183ddc...       | ✅|✅|✅|❓|
| ChOp          | 58f730850eccc2...       | ❌|✅|✅|❓|
| ctranslate2          | v4.5.0       | ❌️️|❌️️|❌️️|❓|
| CUDALibrarySamples          | 5ac0f9a8032a10...       | ❌️️|❌️️|❌️️|❓|
| cuml          | b17f2dbbea05ae...       | ❌️️|❌️️|❌️️|❓|
| cuPHY          | 26.1.1       | ❓|❓|❓|❓|
| cuSZ          | v0.16.2       | ✅|✅|✅|❓|
| cutlass          | v4.1.0       | ❌|❌️️|❌|❓|
| CV-CUDA          | f769fe4bf336ab...       | ❌️️|❌️️|❌️️|❓|
| cycles          | v4.4.0       | ✅|✅|✅|❓|
| deepspeed          | v0.19.7       | ❌|❓|❓|❓|
| DEM-Engine          | c375eae467894a...       | ❌️️|❌️️|❌️️|❓|
| faiss          | v1.9.0       | ❌️️|❌️️|❌️️|❓|
| FastEddy          | v2.0.0       | ✅|✅|✅|❓|
| ffmpeg          | n7.1.3       | ✅|✅|✅|❓|
| FLAMEGPU2          | v2.0.0-rc.2       | ❌️️|❌️️|❌️️|❓|
| ggml          | d3a58b079f50b4...       | ✅|✅|✅|❓|
| ginkgo          | v1.11.0       | ❌|❌|❌|❓|
| gomc          | 4c12477f79dd63...       | ✅|✅|✅|❓|
| gpu_jpeg2k          | ee715e99b6a57a...       | ❌️️|❌️️|❌️️|❓|
| GPUJPEG          | 3e045d1df72735...       | ❌️️|❌️️|❌️️|❓|
| gromacs          | v2026.3       | ✅|❌|✅|❓|
| HARD          | 489e162f435b8e...       | ✅|✅|✅|❓|
| hashcat          | 6716447dfce969...       | ❌|✅|✅|❓|
| hashcat-gfx1100          |        | ❓|❓|❓|❓|
| hashcat-gfx1201          |        | ❓|❓|❓|✅|
| hashcat-gfx90a          |        | ❓|❓|❓|❌|
| hashinator          | 34cf1886ab5f0a...       | ❌️️|❌️️|❌️️|❓|
| HeCBench          | 47f8668f2e933c...       | ✅|✅|✅|❓|
| HiGHS          | v1.15.1       | ❌|❌|❌|❓|
| hoomd-blue          | 5c949015f3fc1a...       | ✅|✅|✅|❓|
| hypre          | v2.33.0       | ❌|❌|❌|❓|
| jitify          | master       | ✅|✅|✅|❓|
| kokkos          | 60d8384266eba9...       | ❌️️|❌️️|❌️️|❓|
| lammps          | stable_22Jul20...       | ✅|✅|✅|❓|
| lammps-kokkos          |        | ✅|✅|✅|❓|
| llama.cpp          | 3ecfb150a4bd2d...       | ❓|✅|✅|❓|
| llm.c          | 7ecd8906afe6ed...       | ❌️️|❌️️|❌️️|❓|
| neko          | v1.1.2       | ❌|❌|❌|❓|
| nixl          | e128059af332df...       | ❌️️|❌️️|❌️️|❓|
| nvflip          | 1eb247cabcf286...       | ✅|✅|✅|❓|
| opencv          | 725e440d278aca...       | ❌️️|❌️️|❌️️|❓|
| openfold3          | v0.5.0       | ❌|❓|❓|❓|
| PhysX          | 1e44a0e2998f06...       | ❌️️|❌️️|❌️️|❓|
| ppisp          | v1.3.0       | ✅|❓|❓|❓|
| pytorch          | v2.9.0       | ❌️️|❌️️|❌️️|❓|
| quda          | 07822b61c6ab5f...       | ❌️️|❌️️|❌️️|❓|
| quokka          | 26.07       | ❌️️|❌️️|❌️️|❓|
| RabbitCT          | main       | ✅|✅|✅|❓|
| risc0          | v1.2.2       | ❌️️|❌️️|❌️️|❓|
| rodinia_suite          | spectral       | ❌|✅|✅|❓|
| stdgpu          | 563dc59d6d08df...       | ✅|❌|✅|❓|
| TCLB          | v6.7       | ✅|✅|✅|❓|
| thrust          | 756c5afc0750f1...       | ✅|✅|✅|❓|
| timemachine          | 01f14f8dd49fbd...       | ❓|❓|❓|❓|
| tsne-cuda          | 4.0.1       | ✅|✅|✅|❓|
| UppASD          | gpu_new       | ✅|✅|✅|❓|
| vllm          | v0.13.0       | ❌️️|❌️️|❌️️|❓|
| warp          | v1.14.0       | ❌️️|❌️️|❌️️|❓|
| whispercpp          | v1.7.1       | ❓|✅|✅|❓|
| whispercpp-gfx1100          |        | ❓|❓|❓|✅|
| whispercpp-gfx1201          |        | ❓|❓|❓|❓|
| whispercpp-gfx90a          |        | ❓|❓|❓|❓|
| xgboost          | v2.1.0       | ❌️️|❌️️|❌️️|❓|

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ❓ Validation skipped
* ❌️️ Tested, but not expected to pass

Pipeline ID: 40987.

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