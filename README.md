# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for geoff-dev-repo: master <790246e1>.**

Test scripts get added to this repository long before they are fully
supported by SCALE. We use the outcome of this kind of testing to prioritise
development. Contributions welcome!

This table summarises the current state as of the most recent stable release
of SCALE. "Needs" describes missing CUDA APIs/features that the project
definitely needs. The list may not be exhaustive.

| Project       | Version | Status | Notes                                                 | Needs                                                                     |
|---------------|---------|--------|-------------------------------------------------------|---------------------------------------------------------------------------|
|  Alien  |  error  |  ?  |  Needs patch to remove OpenGL interop  |  OpenGL Interop  |
|  AMGX  |  error  |  ?  |  |  |
|  arrayfire  |  error  |  ?  |  |  cuDNN, more cuSPARSE  |
|  caffe  |  error  |  ?  |  |  |
|  ctranslate2  |  error  |  ?  |  Some intermittent test failures  |  |
|  cuml  |  error  |  ?  |  Buildsystem nonsnse  |  |
|  cuSZ  |  error  |  ?  |  |  |
|  cutlass  |  error  |  ?  |  |  |
|  CV-CUDA  |  error  |  ?  |  |  |
|  cycles  |  error  |  ?  |  |  |
|  faiss  |  error  |  ❓*  |  |  |
|  FastEddy  |  error  |  ?  |  |  |
|  FLAMEGPU2  |  error  |  ?  |  |  |
|  gomc  |  error  |  ❓*  |  |  |
|  GooFit  |  error  |  ?  |  |  Texture Refs  |
|  gpu\_jpeg2k  |  error  |  ?  |  |  |
|  GROMACS  |  error  |  ?  |  |  |
|  ggml  |  error  |  ?  |  Old version works. New version needs more APIs  |  Missing async opcodes  |
|  hashcat  |  error  |  ❓*  |  |  |
|  hashinator  |  error  |  ?  |  |  |
|  hypre  |  error  |  ?  |  Buildsystem nonsense  |  |
|  jitify  |  error  |  ?  |  Some test failures  |  |
|  llama.cpp  |  error  |  ?  |  Old version works. New version needs more APIs  |  More graph APIs, async matmuls  |
|  llm.c  |  error  |  ?  |  Old version builds+runs. New version needs more APIs  |  NVML, cuBLASLt  |
|  MAGMA  |  error  |  ?  |  |  |
|  nvflip  |  error  |  ?  |  |  |
|  OpenCV  |  error  |  ?  |  |  NPP  |
|  openmpi  |  error  |  ?  |  |  |
|  PhysX  |  error  |  ?  |  Numerous missing APIs  |  PTX barriers, cudaArray, graphics interop  |
|  pytorch  |  error  |  ?  |  Numerous missing APIs  |  cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,...  |
|  quda  |  error  |  ?  |  |  NVML  |
|  risc0  |  error  |  ?  |  Dependent project tries to return carry-bit. Fixable.  |  |
|  rodinia\_suite  |  error  |  ?  |  |  |
|  stdgpu  |  error  |  ❓*  |  Multigpu/crash tests are flaky  |  |
|  TCLB  |  error  |  ?  |  |  |
|  thrust  |  error  |  ❓*  |  Old. Should add `cccl`!  |  |
|  timemachine  |  error  |  ?  |  Buildsystem nonsense  |  |
|  UppASD  |  error  |  ?  |  |  |
|  vllm  |  error  |  ?  |  Needs Pytorch  |  |
|  whispercpp  |  error  |  ?  |  |  |
|  xgboost  |  error  |  ?  |  |  |

> \* The following program tests were skipped for geoff-dev-repo: master <790246e1>, and given states are from older versions:
> 
> * thrust
> * hashcat
> * faiss
> * stdgpu
> * gomc

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
