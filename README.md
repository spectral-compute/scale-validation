# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE:\ master\ <3ad69069>.**

Test scripts get added to this repository long before they are fully
supported by SCALE. We use the outcome of this kind of testing to prioritise
development. Contributions welcome!

This table summarises the current state as of the most recent stable release
of SCALE. "Needs" describes missing CUDA APIs/features that the project
definitely needs. The list may not be exhaustive.

| Project | Version | Status | Valid GFX | Notes | Needs |
|---|---|---|---|---|---|
|  Alien  |  scaletest  |  ❓ (\*)  | gfx1201: ❓ (\*) |   Needs patch to remove OpenGL interop  |  OpenGL Interop  |
|  AMGX  |  v2.4.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  arrayfire  |  v3.9.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  cuDNN, more cuSPARSE  |
|  caffe  |  9b891540183ddc...  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  ctranslate2  |  v4.5.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   Some intermittent test failures  |  |
|  cuml  |  b17f2db  |  ❓ (\*)  | gfx900: ❓ (\*) |   Buildsystem nonsnse  |  |
|  cuSZ  |  v0.16.2  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  CUTLASS  |  v4.1.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  CV-CUDA  |  f769fe4  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  cycles  |  v4.4.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  faiss  |  v1.9.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  FastEddy  |  v2.0.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  FLAMEGPU2  |  v2.0.0-rc.2  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  gomc  |  4c12477  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  GooFit  |  v2.3.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  Texture Refs  |
|  gpu\_jpeg2k  |  ee715e9  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  GROMACS  |  v2025.4  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  ggml  |  d3a58b0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   Old version works. New version needs more APIs  |  Missing async opcodes  |
|  hashcat  |  6716447dfce969...  |  ❓ (\*)  | gfx1100: ❓ (\*) |   |  |
|  hashinator  |  34cf188  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  hypre  |  v2.33.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   Buildsystem nonsense  |  |
|  jitify  |  master  |  ❓ (\*)  | gfx1201: ❓ (\*) |   Some test failures  |  |
|  llama.cpp  |    |  ❓ (\*)  | gfx900: ❓ (\*) |   Old version works. New version needs more APIs  |  More graph APIs, async matmuls  |
|  llm.c  |  7ecd8906afe6ed...  |  ❓ (\*)  | gfx900: ❓ (\*) |   Old version builds+runs. New version needs more APIs  |  NVML, cuBLASLt  |
|  MAGMA  |  v2.9.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  nvflip  |  1eb247c  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  OpenCV  |  725e440  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  NPP  |
|  openmpi  |  v4.1  |  ✅  |  |  No included tests, based on library build validity  |  |
|  PhysX  |  1e44a0e  |  ❓ (\*)  | gfx900: ❓ (\*) |   Numerous missing APIs  |  PTX barriers, cudaArray, graphics interop  |
|  pytorch  |  v2.2.1  |  ❓ (\*)  | gfx900: ❓ (\*) |   Numerous missing APIs  |  cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,...  |
|  quda  |  07822b61c6ab5f...  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  NVML  |
|  risc0  |  v1.2.2  |  ❓ (\*)  | gfx900: ❓ (\*) |   Dependent project tries to return carry-bit. Fixable.  |  |
|  rodinia\_suite  |    |  ❓ (\*)  | gfx1100: ❓ (\*) |   |  |
|  stdgpu  |  563dc59d6d08df...  |  ❓ (\*)  | gfx1100: ❓ (\*) |   Multigpu/crash tests are flaky  |  |
|  TCLB  |  v6.7  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  thrust  |  756c5af  |  ❓ (\*)  | gfx900: ❓ (\*) |   Old. Should add `cccl`!  |  |
|  timemachine  |  01f14f8  |  ❓ (\*)  | gfx900: ❓ (\*) |   Buildsystem nonsense  |  |
|  UppASD  |  gpu_new  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  vllm  |  v0.6.3  |  ❓ (\*)  | gfx900: ❓ (\*) |   Needs Pytorch  |  |
|  whispercpp  |    |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  xgboost  |  v2.1.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ➖ Conflicting statuses, see notes for different architectures
* ✅ (\*) Validation skipped, last known status was Valid
* ❌ (\*) Validation skipped, last known status was Invalid
* ❓ (\*) Validation skipped, no previous validation state to reference


> \* The following program tests were skipped for SCALE:\ master\ <3ad69069>, and given states are from the last version they were tested on instead:
> 
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
> * UppASD
> * TCLB
> * caffe
> * whisper.cpp
> * ggml
> * FastEddy
> * GROMACS
> * cycles
> * hashcat
> * GPUJPEG
> * alien
> * rodinia
> * stdgpu
> * gomc
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
> * rodinia
> * stdgpu
> * gomc
> * faiss
> * cycles
> * faiss
> * TCLB
> * whisper.cpp
> * whisper.cpp
> * alien
> * GPUJPEG
> * ctranslate2
> * jitify
> * FLAMEGPU2
> * TCLB
> * ggml
> * FastEddy
> * GROMACS
> * cuSZ
> * bitnet
> * nvflip
> * UppASD
> * caffe
> * hashcat
> * rodinia
> * stdgpu
> * gomc
> * faiss
> * cycles
> * alien
> * ggml
> * GPUJPEG
> * alien
> * hashcat
> * rodinia
> * stdgpu
> * gomc
> * cuSZ
> * bitnet
> * faiss
> * cycles
> * GPUJPEG
> * nvflip
> * ctranslate2
> * jitify
> * FLAMEGPU2
> * ctranslate2
> * jitify
> * FastEddy
> * GROMACS
> * cuSZ
> * bitnet
> * nvflip
> * UppASD
> * caffe
> * hashcat
> * rodinia
> * stdgpu
> * FLAMEGPU2
> * CUTLASS
> * gpu_jpeg2k
> * gpu_jpeg2k
> * xgboost
> * llama-cpp
> * llm.c
> * quda
> * hypre
> * pytorch
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
> * CUTLASS
> * xgboost
> * llama-cpp
> * llm.c
> * quda
> * hypre
> * pytorch
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
> * xgboost
> * llama-cpp
> * llm.c
> * quda
> * hypre
> * pytorch
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
> * llama-cpp
> * llm.c
> * hashinator
> * MAGMA
> * quda
> * opencv
> * PhysX
> * risc0
> * hypre
> * pytorch
> * thrust
> * AMGX
> * vllm
> * arrayfire
> * cuml
> * gpu_jpeg2k
> * CV-CUDA
> * CUTLASS
> * GooFit
> * xgboost
> * llm.c
> * quda
> * CUTLASS
> * hypre
> * xgboost
> * pytorch
> * thrust
> * AMGX
> * arrayfire
> * cuml
> * CV-CUDA
> * GooFit
> * hashinator
> * llama-cpp
> * MAGMA
> * timemachine
> * vllm
> * opencv
> * PhysX
> * gpu_jpeg2k
> * risc0
> * timemachine
> * vllm

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
