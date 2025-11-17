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
|  Alien  |  alien scaletest
  |  ?  |  Needs patch to remove OpenGL interop  |  OpenGL Interop  |
|  AMGX  |  AMGX v2.4.0
  |  ?  |  |  |
|  arrayfire  |  arrayfire v3.9.0
  |  ?  |  |  cuDNN, more cuSPARSE  |
|  caffe  |  caffe 9b891540183ddc834a02b2bd81b31afae71b2153
  |  ?  |  |  |
|  ctranslate2  |  ctranslate2 v4.5.0
  |  ?  |  Some intermittent test failures  |  |
|  cuml  |  cuml b17f2db
  |  ?  |  Buildsystem nonsnse  |  |
|  cuSZ  |  cuSZ v0.16.2
  |  ?  |  |  |
|  cutlass  |  cutlass v4.1.0
  |  ?  |  |  |
|  CV-CUDA  |  CV-CUDA f769fe4
  |  ?  |  |  |
|  cycles  |  cycles v4.4.0
  |  ?  |  |  |
|  faiss  |  faiss v1.9.0
  |  ❓*  |  |  |
|  FastEddy  |  FastEddy v2.0.0
  |  ?  |  |  |
|  FLAMEGPU2  |  FLAMEGPU2 v2.0.0-rc.2
  |  ?  |  |  |
|  gomc  |  GOMC 4c12477
GOMC_Examples cec1be7
  |  ❓*  |  |  |
|  GooFit  |  GooFit v2.3.0
  |  ?  |  |  Texture Refs  |
|  gpu\_jpeg2k  |  gpu_jpeg2k ee715e9
  |  ?  |  |  |
|  GROMACS  |  error  |  ?  |  |  |
|  ggml  |  ggml d3a58b0
  |  ?  |  Old version works. New version needs more APIs  |  Missing async opcodes  |
|  hashcat  |  hashcat 6716447dfce969ddde42a9abe0681500bee0df48
  |  ❓*  |  |  |
|  hashinator  |  hashinator 34cf188
  |  ?  |  |  |
|  hypre  |  hypre v2.33.0
  |  ?  |  Buildsystem nonsense  |  |
|  jitify  |  jitify master
  |  ?  |  Some test failures  |  |
|  llama.cpp  |  llama.cpp b2000
  |  ?  |  Old version works. New version needs more APIs  |  More graph APIs, async matmuls  |
|  llm.c  |  llm.c 7ecd8906afe6ed7a2b2cdb731c042f26d525b820
  |  ?  |  Old version builds+runs. New version needs more APIs  |  NVML, cuBLASLt  |
|  MAGMA  |  MAGMA v2.9.0
  |  ?  |  |  |
|  nvflip  |  nvflip 1eb247c
  |  ?  |  |  |
|  OpenCV  |  error  |  ?  |  |  NPP  |
|  openmpi  |  error  |  ?  |  |  |
|  PhysX  |  error  |  ?  |  Numerous missing APIs  |  PTX barriers, cudaArray, graphics interop  |
|  pytorch  |  pytorch v2.2.1
  |  ?  |  Numerous missing APIs  |  cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,...  |
|  quda  |  quda 07822b61c6ab5fa9586233b03ac794bf33ab647e
  |  ?  |  |  NVML  |
|  risc0  |  risc0 v1.2.2
  |  ?  |  Dependent project tries to return carry-bit. Fixable.  |  |
|  rodinia\_suite  |  rodinia_suite spectral
  |  ?  |  |  |
|  stdgpu  |  stdgpu 563dc59d6d08dfaa0adbbcbd8dc079c1a78a2a79
  |  ❓*  |  Multigpu/crash tests are flaky  |  |
|  TCLB  |  TCLB v6.7
  |  ?  |  |  |
|  thrust  |  thrust 756c5af
  |  ❓*  |  Old. Should add `cccl`!  |  |
|  timemachine  |  timemachine 01f14f8
  |  ?  |  Buildsystem nonsense  |  |
|  UppASD  |  UppASD gpu_new
  |  ?  |  |  |
|  vllm  |  vllm v0.6.3
  |  ?  |  Needs Pytorch  |  |
|  whispercpp  |  whispercpp v1.7.1
  |  ?  |  |  |
|  xgboost  |  xgboost v2.1.0
House-Prices-Advanced-Regression f3a41e6
datasets 5e987d5
  |  ?  |  |  |

> \* The following program tests were skipped for geoff-dev-repo: master <790246e1>, and given states are from older versions:
> 
> * hashcat
> * stdgpu
> * gomc
> * thrust
> * faiss

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
