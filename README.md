# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE:\ master\ <d6d7d664>.**

Test scripts get added to this repository long before they are fully
supported by SCALE. We use the outcome of this kind of testing to prioritise
development. Contributions welcome!

This table summarises the current state as of the most recent stable release
of SCALE. "Needs" describes missing CUDA APIs/features that the project
definitely needs. The list may not be exhaustive.

| Project | Version | Status | Valid GFX | Notes | Needs |
|---|---|---|---|---|---|
|  Alien  |  scaletest  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   Needs patch to remove OpenGL interop  |  OpenGL Interop  |
|  AMGX  |  v2.4.0  |  ➖  | gfx1201: ✅, gfx1100: ✅, gfx906: ✅, gfx1030: ❌ |   |  |
|  arrayfire  |  v3.9.0  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  cuDNN, more cuSPARSE  |
|  caffe  |  9b891540183ddc...  |  ➖  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ❌ |   |  |
|  ctranslate2  |  v4.5.0  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   Some intermittent test failures  |  |
|  cuml  |  b17f2db  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Buildsystem nonsnse  |  |
|  cuSZ  |  v0.16.2  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  CUTLASS  |  v4.1.0  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  |
|  CV-CUDA  |  f769fe4  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  |
|  cycles  |  v4.4.0  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  faiss  |  v1.9.0  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  |
|  FastEddy  |  v2.0.0  |  ➖  | gfx1201: ✅, gfx1100: ✅, gfx906: ✅, gfx1030: ❌ |   |  |
|  FLAMEGPU2  |  v2.0.0-rc.2  |  ➖  | gfx1100: ✅, gfx1030: ✅, gfx1201: ❌, gfx906: ❌ |   |  |
|  gomc  |  4c12477  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  GooFit  |  v2.3.0  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  Texture Refs  |
|  gpu\_jpeg2k  |  ee715e9  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  |
|  GROMACS  |  v2025.4  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  ggml  |  d3a58b0  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   Old version works. New version needs more APIs  |  Missing async opcodes  |
|  hashcat  |  6716447dfce969...  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  hashinator  |  34cf188  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  |
|  hypre  |  v2.33.0  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Buildsystem nonsense  |  |
|  jitify  |  master  |  ➖  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ❌ |   Some test failures  |  |
|  llama.cpp  |    |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Old version works. New version needs more APIs  |  More graph APIs, async matmuls  |
|  llm.c  |  7ecd8906afe6ed...  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Old version builds+runs. New version needs more APIs  |  NVML, cuBLASLt  |
|  MAGMA  |  v2.9.0  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  |
|  nvflip  |  1eb247c  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  OpenCV  |  725e440  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  NPP  |
|  openmpi  |  v4.1  |  ✅  |  |  No included tests, based on library build validity  |  |
|  PhysX  |  1e44a0e  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Numerous missing APIs  |  PTX barriers, cudaArray, graphics interop  |
|  pytorch  |  v2.2.1  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Numerous missing APIs  |  cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,...  |
|  quda  |  07822b61c6ab5f...  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  NVML  |
|  risc0  |  v1.2.2  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Dependent project tries to return carry-bit. Fixable.  |  |
|  rodinia\_suite  |    |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  stdgpu  |  563dc59d6d08df...  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   Multigpu/crash tests are flaky  |  |
|  TCLB  |  v6.7  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  thrust  |  756c5af  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Old. Should add `cccl`!  |  |
|  timemachine  |  01f14f8  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Buildsystem nonsense  |  |
|  UppASD  |  gpu_new  |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  vllm  |  v0.6.3  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   Needs Pytorch  |  |
|  whispercpp  |    |  ✅  | gfx1201: ✅, gfx1100: ✅, gfx1030: ✅, gfx906: ✅ |   |  |
|  xgboost  |  v2.1.0  |  ❌  | gfx1201: ❌, gfx1100: ❌, gfx1030: ❌, gfx906: ❌ |   |  |

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
