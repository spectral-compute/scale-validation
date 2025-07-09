# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

Test scripts get added to this repository long before they are fully
supported by SCALE. We use the outcome of this kind of testing to prioritise
development. Contributions welcome!

This table summarises the current state as of the most recent stable release
of SCALE. "Needs" describes missing CUDA APIs/features that the project
definitely needs. The list may not be exhaustive.

| Project       | Status | Notes                                                 | Needs                                                                     |
|---------------|--------|-------------------------------------------------------|---------------------------------------------------------------------------|
| Alien         | ✔*     | Needs patch to remove OpenGL interop                  | OpenGL Interop                                                            |
| AMGX          | ✔      |                                                       |                                                                           |
| arrayfire     | ❌      |                                                       | cuDNN, more cuSPARSE                                                      |
| caffe         | ✔      |                                                       |                                                                           |
| ctranslate2   | ✔*     | Some intermittent test failures                       |                                                                           |
| cuml          | ❌      | Buildsystem nonsnse                                   |                                                                           |
| cuSZ          | ❌      |                                                       | NVML                                                                      |
| cutlass       | ❌      |                                                       |                                                                           |
| CV-CUDA       | ❌      |                                                       |                                                                           |
| cycles        | ✔      |                                                       |                                                                           |
| faiss         | ✔      |                                                       |                                                                           |
| FastEddy      | ✔      |                                                       |                                                                           |
| FLAMEGPU2     | ✔      |                                                       |                                                                           |
| gomc          | ✔      |                                                       |                                                                           |
| GooFit        | ❌      |                                                       | Texture Refs                                                              |
| gpu_jpeg2k    | ✔      |                                                       |                                                                           |
| GROMACS       | ✔      |                                                       |                                                                           |
| ggml          | ✔*     | Old version works. New version needs more APIs        | Missing async opcodes                                                     |
| hashcat       | ✔      |                                                       |                                                                           |
| hashinator    | ✔      |                                                       |                                                                           |
| hypre         | ❌      | Buildsystem nonsense                                  |                                                                           |
| jitify        | ✔*     | Some test failures                                    |                                                                           |
| llama.cpp     | ✔****  | Old version works. New version needs more APIs        | More graph APIs, async matmuls                                            |
| llm.c         | ❌      | Old version builds+runs. New version needs more APIs  | NVML, cuBLASLt                                                            |
| MAGMA         | ✔      |                                                       |                                                                           |
| OpenCV        | ❌      |                                                       | NPP                                                                       |
| openmpi       | ✔      |                                                       |                                                                           |
| PhysX         | ❌      | Numerous missing APIs                                 | PTX barriers, cudaArray, graphics interop                                 |
| pytorch       | ❌      | Numerous missing APIs                                 | cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,... |
| quda          | ❌      |                                                       | NVML                                                                      |
| risc0         | ❌      | Dependent project tries to return carry-bit. Fixable. |                                                                           |
| rodinia_suite | ✔      |                                                       |                                                                           |
| stdgpu        | ✔*     | Multigpu/crash tests are flaky                        |                                                                           |
| TCLB          | ✔      |                                                       |                                                                           |
| thrust        | ✔      | Old. Should add `cccl`!                               |                                                                           |
| timemachine   | ❌      | Buildsystem nonsense                                  |                                                                           |
| UppASD        | ✔      |                                                       |                                                                           |
| vllm          | ❌      | Needs Pytorch                                         |                                                                           |
| whispercpp    | ✔      |                                                       |                                                                           |
| xgboost       | ✔      |                                                       |                                                                           |

## Running Tests

Each directory (except `util`) contains a set of scripts that should be executed
in lexicographical order for a complete test. These scripts are mostly just
the normal CUDA build instructions for the corresponding project.

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
