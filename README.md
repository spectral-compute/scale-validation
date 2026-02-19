# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE:\ master\ <93892376>.**

Test scripts get added to this repository long before they are fully
supported by SCALE. We use the outcome of this kind of testing to prioritise
development. Contributions welcome!

This table summarises the current state as of the most recent stable release
of SCALE. "Needs" describes missing CUDA APIs/features that the project
definitely needs. The list may not be exhaustive.

| Project | Version | Status | Valid GFX | Notes | Needs |
|---|---|---|---|---|---|
|  Alien  |  scaletest  |  ❌ (\*)  | gfx906: ❌ (\*) |   Needs patch to remove OpenGL interop  |  OpenGL Interop  |
|  AMGX  |  v2.4.0  |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  |
|  arrayfire  |  v3.9.0  |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  cuDNN, more cuSPARSE  |
|  caffe  |  9b891540183ddc...  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  ctranslate2  |  v4.5.0  |  ❌ (\*)  | gfx906: ❌ (\*) |   Some intermittent test failures  |  |
|  cuml  |  b17f2db  |  ❌ (\*)  | gfx1030: ❌ (\*) |   Buildsystem nonsnse  |  |
|  cuSZ  |  v0.16.2  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  CUTLASS  |  v4.1.0  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  CV-CUDA  |  f769fe4  |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  |
|  cycles  |  v4.4.0  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  faiss  |  v1.9.0  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  FastEddy  |  v2.0.0  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  FLAMEGPU2  |  v2.0.0-rc.2  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  gomc  |  4c12477  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  GooFit  |  v2.3.0  |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  Texture Refs  |
|  gpu\_jpeg2k  |  ee715e9  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  GROMACS  |  v2025.4  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  ggml  |  d3a58b0  |  ❌ (\*)  | gfx906: ❌ (\*) |   Old version works. New version needs more APIs  |  Missing async opcodes  |
|  hashcat  |  6716447dfce969...  |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  |
|  hashinator  |  34cf188  |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  |
|  hypre  |  v2.33.0  |  ❌ (\*)  | gfx1030: ❌ (\*) |   Buildsystem nonsense  |  |
|  jitify  |  master  |  ❌ (\*)  | gfx906: ❌ (\*) |   Some test failures  |  |
|  llama.cpp  |    |  ❌ (\*)  | gfx906: ❌ (\*) |   Old version works. New version needs more APIs  |  More graph APIs, async matmuls  |
|  llm.c  |  7ecd8906afe6ed...  |  ❌ (\*)  | gfx906: ❌ (\*) |   Old version builds+runs. New version needs more APIs  |  NVML, cuBLASLt  |
|  MAGMA  |  v2.9.0  |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  |
|  nvflip  |  1eb247c  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  OpenCV  |  725e440  |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  NPP  |
|  openmpi  |  v4.1  |  ✅  |  |  No included tests, based on library build validity  |  |
|  PhysX  |  1e44a0e  |  ❌ (\*)  | gfx906: ❌ (\*) |   Numerous missing APIs  |  PTX barriers, cudaArray, graphics interop  |
|  pytorch  |  v2.2.1  |  ❌ (\*)  | gfx1030: ❌ (\*) |   Numerous missing APIs  |  cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,...  |
|  quda  |  07822b61c6ab5f...  |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  NVML  |
|  risc0  |  v1.2.2  |  ❌ (\*)  | gfx906: ❌ (\*) |   Dependent project tries to return carry-bit. Fixable.  |  |
|  rodinia\_suite  |    |  ❌ (\*)  | gfx1030: ❌ (\*) |   |  |
|  stdgpu  |  563dc59d6d08df...  |  ❌ (\*)  | gfx1030: ❌ (\*) |   Multigpu/crash tests are flaky  |  |
|  TCLB  |  v6.7  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  thrust  |  756c5af  |  ❌ (\*)  | gfx1030: ❌ (\*) |   Old. Should add `cccl`!  |  |
|  timemachine  |  01f14f8  |  ❌ (\*)  | gfx906: ❌ (\*) |   Buildsystem nonsense  |  |
|  UppASD  |  gpu_new  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  vllm  |  v0.6.3  |  ❌ (\*)  | gfx906: ❌ (\*) |   Needs Pytorch  |  |
|  whispercpp  |    |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |
|  xgboost  |  v2.1.0  |  ❌ (\*)  | gfx906: ❌ (\*) |   |  |

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ➖ Conflicting statuses, see notes for different architectures
* ✅ (\*) Validation skipped, last known status was Valid
* ❌ (\*) Validation skipped, last known status was Invalid
* ❓ (\*) Validation skipped, no previous validation state to reference


> \* The following program tests were skipped for SCALE:\ master\ <93892376>, and given states are from the last version they were tested on instead:
> 
> * stdgpu
> * FLAMEGPU2
> * TCLB
> * whisper.cpp
> * ggml
> * FastEddy
> * GROMACS
> * cuSZ
> * bitnet
> * nvflip
> * UppASD
> * caffe
> * hashcat
> * gomc
> * faiss
> * cycles
> * alien
> * GPUJPEG
> * ctranslate2
> * jitify
> * rodinia
> * gomc
> * faiss
> * cycles
> * alien
> * GPUJPEG
> * ctranslate2
> * jitify
> * FLAMEGPU2
> * TCLB
> * hashcat
> * rodinia
> * stdgpu
> * rodinia
> * stdgpu
> * jitify
> * FLAMEGPU2
> * whisper.cpp
> * ggml
> * FastEddy
> * GROMACS
> * cuSZ
> * bitnet
> * nvflip
> * UppASD
> * caffe
> * hashcat
> * FLAMEGPU2
> * TCLB
> * whisper.cpp
> * ggml
> * FastEddy
> * GROMACS
> * gomc
> * faiss
> * cycles
> * alien
> * GPUJPEG
> * ctranslate2
> * hashcat
> * rodinia
> * stdgpu
> * gomc
> * faiss
> * cycles
> * cuSZ
> * bitnet
> * nvflip
> * UppASD
> * alien
> * GPUJPEG
> * ctranslate2
> * jitify
> * TCLB
> * whisper.cpp
> * ggml
> * FastEddy
> * GROMACS
> * cuSZ
> * bitnet
> * nvflip
> * UppASD
> * caffe
> * cycles:sm_89
> * alien:sm_89
> * GPUJPEG:sm_89
> * caffe
> * hashcat:sm_89
> * rodinia:sm_89
> * stdgpu:sm_89
> * gomc:sm_89
> * faiss:sm_89
> * ctranslate2:sm_89
> * jitify:sm_89
> * FLAMEGPU2:sm_89
> * TCLB:sm_89
> * whisper.cpp:sm_89
> * ggml:sm_89
> * FastEddy:sm_89
> * GROMACS:sm_89
> * cuSZ:sm_89
> * bitnet:sm_89
> * nvflip:sm_89
> * UppASD:sm_89
> * caffe:sm_89
> * gpu_jpeg2k
> * CUTLASS
> * xgboost
> * llama-cpp
> * llm.c
> * PhysX
> * risc0
> * timemachine
> * vllm
> * gpu_jpeg2k
> * CUTLASS
> * xgboost
> * llama-cpp
> * llm.c
> * quda
> * opencv:sm_89
> * PhysX:sm_89
> * risc0:sm_89
> * timemachine:sm_89
> * vllm:sm_89
> * AMGX:sm_89
> * arrayfire:sm_89
> * cuml:sm_89
> * CV-CUDA:sm_89
> * GooFit:sm_89
> * hashinator:sm_89
> * MAGMA:sm_89
> * MAGMA
> * opencv
> * PhysX
> * risc0
> * timemachine
> * vllm
> * gpu_jpeg2k
> * CUTLASS
> * hypre
> * pytorch
> * HeCBench
> * thrust
> * AMGX
> * arrayfire
> * cuml
> * CV-CUDA
> * GooFit
> * hashinator
> * xgboost
> * llama-cpp
> * quda
> * hypre
> * pytorch
> * HeCBench
> * thrust
> * AMGX
> * arrayfire
> * cuml
> * CV-CUDA
> * GooFit
> * hashinator
> * MAGMA
> * opencv
> * xgboost
> * llama-cpp
> * llm.c
> * quda
> * hypre
> * pytorch
> * HeCBench
> * thrust
> * AMGX
> * arrayfire
> * quda
> * hypre
> * pytorch
> * HeCBench
> * thrust
> * AMGX
> * arrayfire
> * cuml
> * CV-CUDA
> * GooFit
> * hashinator
> * MAGMA
> * opencv
> * PhysX
> * risc0
> * timemachine
> * vllm
> * gpu_jpeg2k
> * CUTLASS
> * llm.c
> * cuml
> * CV-CUDA
> * GooFit
> * hashinator
> * MAGMA
> * opencv
> * PhysX
> * risc0
> * timemachine
> * vllm
> * gpu_jpeg2k:sm_89
> * CUTLASS:sm_89
> * xgboost:sm_89
> * llama-cpp:sm_89
> * llm.c:sm_89
> * quda:sm_89
> * hypre:sm_89
> * pytorch:sm_89
> * HeCBench:sm_89
> * thrust:sm_89

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
