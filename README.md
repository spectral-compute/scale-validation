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
|  Alien  |  YWxpZW4gc2NhbGV0ZXN0Cg==
  |  ?  |  Needs patch to remove OpenGL interop  |  OpenGL Interop  |
|  AMGX  |  QU1HWCB2Mi40LjAK
  |  ?  |  |  |
|  arrayfire  |  YXJyYXlmaXJlIHYzLjkuMAo=
  |  ?  |  |  cuDNN, more cuSPARSE  |
|  caffe  |  Y2FmZmUgOWI4OTE1NDAxODNkZGM4MzRhMDJiMmJkODFiMzFhZmFlNzFiMjE1
Mwo=
  |  ?  |  |  |
|  ctranslate2  |  Y3RyYW5zbGF0ZTIgdjQuNS4wCg==
  |  ?  |  Some intermittent test failures  |  |
|  cuml  |  Y3VtbCBiMTdmMmRiCg==
  |  ?  |  Buildsystem nonsnse  |  |
|  cuSZ  |  Y3VTWiB2MC4xNi4yCg==
  |  ?  |  |  |
|  cutlass  |  Y3V0bGFzcyB2NC4xLjAK
  |  ?  |  |  |
|  CV-CUDA  |  Q1YtQ1VEQSBmNzY5ZmU0Cg==
  |  ?  |  |  |
|  cycles  |  Y3ljbGVzIHY0LjQuMAo=
  |  ?  |  |  |
|  faiss  |  ZmFpc3MgdjEuOS4wCg==
  |  ❓*  |  |  |
|  FastEddy  |  RmFzdEVkZHkgdjIuMC4wCg==
  |  ?  |  |  |
|  FLAMEGPU2  |  RkxBTUVHUFUyIHYyLjAuMC1yYy4yCg==
  |  ?  |  |  |
|  gomc  |  R09NQyA0YzEyNDc3CkdPTUNfRXhhbXBsZXMgY2VjMWJlNwo=
  |  ❓*  |  |  |
|  GooFit  |  R29vRml0IHYyLjMuMAo=
  |  ?  |  |  Texture Refs  |
|  gpu\_jpeg2k  |  Z3B1X2pwZWcyayBlZTcxNWU5Cg==
  |  ?  |  |  |
|  GROMACS  |  error  |  ?  |  |  |
|  ggml  |  Z2dtbCBkM2E1OGIwCg==
  |  ?  |  Old version works. New version needs more APIs  |  Missing async opcodes  |
|  hashcat  |  aGFzaGNhdCA2NzE2NDQ3ZGZjZTk2OWRkZGU0MmE5YWJlMDY4MTUwMGJlZTBk
ZjQ4Cg==
  |  ❓*  |  |  |
|  hashinator  |  aGFzaGluYXRvciAzNGNmMTg4Cg==
  |  ?  |  |  |
|  hypre  |  aHlwcmUgdjIuMzMuMAo=
  |  ?  |  Buildsystem nonsense  |  |
|  jitify  |  aml0aWZ5IG1hc3Rlcgo=
  |  ?  |  Some test failures  |  |
|  llama.cpp  |  bGxhbWEuY3BwIGIyMDAwCg==
  |  ?  |  Old version works. New version needs more APIs  |  More graph APIs, async matmuls  |
|  llm.c  |  bGxtLmMgN2VjZDg5MDZhZmU2ZWQ3YTJiMmNkYjczMWMwNDJmMjZkNTI1Yjgy
MAo=
  |  ?  |  Old version builds+runs. New version needs more APIs  |  NVML, cuBLASLt  |
|  MAGMA  |  TUFHTUEgdjIuOS4wCg==
  |  ?  |  |  |
|  nvflip  |  bnZmbGlwIDFlYjI0N2MK
  |  ?  |  |  |
|  OpenCV  |  error  |  ?  |  |  NPP  |
|  openmpi  |  error  |  ?  |  |  |
|  PhysX  |  error  |  ?  |  Numerous missing APIs  |  PTX barriers, cudaArray, graphics interop  |
|  pytorch  |  cHl0b3JjaCB2Mi4yLjEK
  |  ?  |  Numerous missing APIs  |  cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,...  |
|  quda  |  cXVkYSAwNzgyMmI2MWM2YWI1ZmE5NTg2MjMzYjAzYWM3OTRiZjMzYWI2NDdl
Cg==
  |  ?  |  |  NVML  |
|  risc0  |  cmlzYzAgdjEuMi4yCg==
  |  ?  |  Dependent project tries to return carry-bit. Fixable.  |  |
|  rodinia\_suite  |  cm9kaW5pYV9zdWl0ZSBzcGVjdHJhbAo=
  |  ?  |  |  |
|  stdgpu  |  c3RkZ3B1IDU2M2RjNTlkNmQwOGRmYWEwYWRiYmNiZDhkYzA3OWMxYTc4YTJh
NzkK
  |  ❓*  |  Multigpu/crash tests are flaky  |  |
|  TCLB  |  VENMQiB2Ni43Cg==
  |  ?  |  |  |
|  thrust  |  dGhydXN0IDc1NmM1YWYK
  |  ❓*  |  Old. Should add `cccl`!  |  |
|  timemachine  |  dGltZW1hY2hpbmUgMDFmMTRmOAo=
  |  ?  |  Buildsystem nonsense  |  |
|  UppASD  |  VXBwQVNEIGdwdV9uZXcK
  |  ?  |  |  |
|  vllm  |  dmxsbSB2MC42LjMK
  |  ?  |  Needs Pytorch  |  |
|  whispercpp  |  d2hpc3BlcmNwcCB2MS43LjEK
  |  ?  |  |  |
|  xgboost  |  eGdib29zdCB2Mi4xLjAKSG91c2UtUHJpY2VzLUFkdmFuY2VkLVJlZ3Jlc3Np
b24gZjNhNDFlNgpkYXRhc2V0cyA1ZTk4N2Q1Cg==
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
