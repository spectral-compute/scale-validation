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
|  Alien  |  scaletest  |  ❓ (\*)  | gfx1030: ❓ (\*) |   Needs patch to remove OpenGL interop  |  OpenGL Interop  |
|  AMGX  |  v2.4.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  arrayfire  |  v3.9.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  cuDNN, more cuSPARSE  |
|  caffe  |  9b891540183ddc...  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  ctranslate2  |  v4.5.0  |  ❓ (\*)  | gfx1030: ❓ (\*) |   Some intermittent test failures  |  |
|  cuml  |  b17f2db  |  ❓ (\*)  | gfx1030: ❓ (\*) |   Buildsystem nonsnse  |  |
|  cuSZ  |  v0.16.2  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  CUTLASS  |  v4.1.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  CV-CUDA  |  f769fe4  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  cycles  |  v4.4.0  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  faiss  |  v1.9.0  |  ❓ (\*)  | gfx906: ❓ (\*) |   |  |
|  FastEddy  |  v2.0.0  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  FLAMEGPU2  |  v2.0.0-rc.2  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  gomc  |  4c12477  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  GooFit  |  v2.3.0  |  ❓ (\*)  | gfx1100: ❓ (\*) |   |  Texture Refs  |
|  gpu\_jpeg2k  |  ee715e9  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  GROMACS  |  v2025.4  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  ggml  |  d3a58b0  |  ❓ (\*)  | gfx1030: ❓ (\*) |   Old version works. New version needs more APIs  |  Missing async opcodes  |
|  hashcat  |  6716447dfce969...  |  ❓ (\*)  | gfx1100: ❓ (\*) |   |  |
|  hashinator  |  34cf188  |  ❓ (\*)  | gfx1100: ❓ (\*) |   |  |
|  hypre  |  v2.33.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   Buildsystem nonsense  |  |
|  jitify  |  master  |  ❓ (\*)  | gfx1030: ❓ (\*) |   Some test failures  |  |
|  llama.cpp  |    |  ❓ (\*)  | gfx1201: ❓ (\*) |   Old version works. New version needs more APIs  |  More graph APIs, async matmuls  |
|  llm.c  |  7ecd8906afe6ed...  |  ❓ (\*)  | gfx1201: ❓ (\*) |   Old version builds+runs. New version needs more APIs  |  NVML, cuBLASLt  |
|  MAGMA  |  v2.9.0  |  ❓ (\*)  | gfx1100: ❓ (\*) |   |  |
|  nvflip  |  1eb247c  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  OpenCV  |  725e440  |  ❓ (\*)  | gfx1100: ❓ (\*) |   |  NPP  |
|  openmpi  |  v4.1  |  ✅  |  |  No included tests, based on library build validity  |  |
|  PhysX  |  1e44a0e  |  ❓ (\*)  | gfx1100: ❓ (\*) |   Numerous missing APIs  |  PTX barriers, cudaArray, graphics interop  |
|  pytorch  |  v2.2.1  |  ❓ (\*)  | gfx1201: ❓ (\*) |   Numerous missing APIs  |  cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,...  |
|  quda  |  07822b61c6ab5f...  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  NVML  |
|  risc0  |  v1.2.2  |  ❓ (\*)  | gfx1100: ❓ (\*) |   Dependent project tries to return carry-bit. Fixable.  |  |
|  rodinia\_suite  |    |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  stdgpu  |  563dc59d6d08df...  |  ❓ (\*)  | gfx1030: ❓ (\*) |   Multigpu/crash tests are flaky  |  |
|  TCLB  |  v6.7  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  thrust  |  756c5af  |  ❓ (\*)  | gfx1201: ❓ (\*) |   Old. Should add `cccl`!  |  |
|  timemachine  |  01f14f8  |  ❓ (\*)  | gfx1100: ❓ (\*) |   Buildsystem nonsense  |  |
|  UppASD  |  gpu_new  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  vllm  |  v0.6.3  |  ❓ (\*)  | gfx1100: ❓ (\*) |   Needs Pytorch  |  |
|  whispercpp  |    |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  xgboost  |  v2.1.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ➖ Conflicting statuses, see notes for different architectures
* ✅ (\*) Validation skipped, last known status was Valid
* ❌ (\*) Validation skipped, last known status was Invalid
* ❓ (\*) Validation skipped, no previous validation state to reference


> \* The following program tests were skipped for SCALE:\ master\ <d6d7d664>, and given states are from the last version they were tested on instead:
> 
> * bitnet:rtx5070ti
> * nvflip:rtx5070ti
> * caffe
> * hashcat:rtx5070ti
> * rodinia:rtx5070ti
> * stdgpu:rtx5070ti
> * gomc:rtx5070ti
> * faiss:rtx5070ti
> * cycles:rtx5070ti
> * alien:rtx5070ti
> * GPUJPEG:rtx5070ti
> * ctranslate2:rtx5070ti
> * jitify:rtx5070ti
> * FLAMEGPU2:rtx5070ti
> * TCLB:rtx5070ti
> * whisper.cpp:rtx5070ti
> * ggml:rtx5070ti
> * FastEddy:rtx5070ti
> * GROMACS:rtx5070ti
> * cycles
> * alien
> * GPUJPEG
> * ctranslate2
> * jitify
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
> * stdgpu
> * GROMACS
> * caffe
> * whisper.cpp
> * gomc
> * cuSZ
> * bitnet
> * FLAMEGPU2
> * TCLB
> * hashcat
> * rodinia
> * ggml
> * gomc
> * faiss
> * cycles
> * alien
> * GPUJPEG
> * FastEddy
> * ctranslate2
> * jitify
> * cuSZ:rtx5070ti
> * stdgpu
> * gomc
> * faiss
> * cycles
> * alien
> * GPUJPEG
> * ctranslate2
> * jitify
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
> * faiss
> * rodinia
> * nvflip
> * UppASD
> * hashcat
> * rodinia
> * stdgpu
> * hashcat
> * rodinia
> * stdgpu
> * gomc
> * faiss
> * cycles
> * alien
> * GPUJPEG
> * ctranslate2
> * jitify
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
> * UppASD:rtx5070ti
> * caffe:rtx5070ti
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
> * timemachine
> * llm.c
> * HeCBench
> * thrust
> * vllm
> * AMGX
> * quda
> * arrayfire
> * hypre
> * cuml
> * CV-CUDA
> * GooFit
> * hashinator
> * gpu_jpeg2k
> * CUTLASS
> * arrayfire:rtx5070ti
> * cuml:rtx5070ti
> * pytorch
> * xgboost
> * llama-cpp
> * risc0
> * PhysX
> * CV-CUDA:rtx5070ti
> * GooFit:rtx5070ti
> * hashinator:rtx5070ti
> * MAGMA:rtx5070ti
> * opencv:rtx5070ti
> * PhysX:rtx5070ti
> * risc0:rtx5070ti
> * timemachine:rtx5070ti
> * vllm:rtx5070ti
> * AMGX:rtx5070ti
> * gpu_jpeg2k
> * CUTLASS
> * xgboost
> * llama-cpp
> * llm.c
> * hashinator
> * MAGMA
> * quda
> * hypre
> * pytorch
> * opencv
> * HeCBench
> * thrust
> * AMGX
> * arrayfire
> * cuml
> * CV-CUDA
> * GooFit
> * MAGMA
> * opencv
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
> * hypre
> * pytorch
> * HeCBench
> * thrust
> * AMGX
> * arrayfire
> * cuml
> * CV-CUDA
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
> * gpu_jpeg2k:rtx5070ti
> * CUTLASS:rtx5070ti
> * xgboost:rtx5070ti
> * llama-cpp:rtx5070ti
> * llm.c:rtx5070ti
> * quda:rtx5070ti
> * hypre:rtx5070ti
> * pytorch:rtx5070ti
> * HeCBench:rtx5070ti
> * thrust:rtx5070ti

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
