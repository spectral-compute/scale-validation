# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE:\ master\ <408e2f7e>.**

Test scripts get added to this repository long before they are fully
supported by SCALE. We use the outcome of this kind of testing to prioritise
development. Contributions welcome!

This table summarises the current state as of the most recent stable release
of SCALE. "Needs" describes missing CUDA APIs/features that the project
definitely needs. The list may not be exhaustive.

| Project | Version | Status | Valid GFX | Notes | Needs |
|---|---|---|---|---|---|
|  Alien  |  scaletest  |  ❓ (\*)  | gfx90a: ❓ (\*) |   Needs patch to remove OpenGL interop  |  OpenGL Interop  |
|  AMGX  |  v2.4.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  arrayfire  |  v3.9.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  cuDNN, more cuSPARSE  |
|  caffe  |  9b891540183ddc...  |  ❓ (\*)  | gfx90a: ❓ (\*) |   |  |
|  ctranslate2  |  v4.5.0  |  ❓ (\*)  | gfx90a: ❓ (\*) |   Some intermittent test failures  |  |
|  cuml  |  b17f2db  |  ❓ (\*)  | gfx900: ❓ (\*) |   Buildsystem nonsnse  |  |
|  cuSZ  |  v0.16.2  |  ❓ (\*)  | gfx90a: ❓ (\*) |   |  |
|  CUTLASS  |  v4.1.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  CV-CUDA  |  f769fe4  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  cycles  |  v4.4.0  |  ❓ (\*)  | gfx90a: ❓ (\*) |   |  |
|  faiss  |  v1.9.0  |  ❓ (\*)  | gfx90a: ❓ (\*) |   |  |
|  FastEddy  |  v2.0.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  FLAMEGPU2  |  v2.0.0-rc.2  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  gomc  |  4c12477  |  ❓ (\*)  | gfx90a: ❓ (\*) |   |  |
|  GooFit  |  v2.3.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  Texture Refs  |
|  gpu\_jpeg2k  |  ee715e9  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |
|  GROMACS  |  v2025.4  |  ❓ (\*)  | gfx90a: ❓ (\*) |   |  |
|  ggml  |  d3a58b0  |  ❓ (\*)  | gfx90a: ❓ (\*) |   Old version works. New version needs more APIs  |  Missing async opcodes  |
|  hashcat  |  6716447dfce969...  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  hashinator  |  34cf188  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  hypre  |  v2.33.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   Buildsystem nonsense  |  |
|  jitify  |  master  |  ❓ (\*)  | gfx90a: ❓ (\*) |   Some test failures  |  |
|  llama.cpp  |    |  ❓ (\*)  | gfx900: ❓ (\*) |   Old version works. New version needs more APIs  |  More graph APIs, async matmuls  |
|  llm.c  |  7ecd8906afe6ed...  |  ❓ (\*)  | gfx900: ❓ (\*) |   Old version builds+runs. New version needs more APIs  |  NVML, cuBLASLt  |
|  MAGMA  |  v2.9.0  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  nvflip  |  1eb247c  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  OpenCV  |  725e440  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  NPP  |
|  openmpi  |  v4.1  |  ✅  |  |  No included tests, based on library build validity  |  |
|  PhysX  |  1e44a0e  |  ❓ (\*)  | gfx1201: ❓ (\*) |   Numerous missing APIs  |  PTX barriers, cudaArray, graphics interop  |
|  pytorch  |  v2.2.1  |  ❓ (\*)  | gfx900: ❓ (\*) |   Numerous missing APIs  |  cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,...  |
|  quda  |  07822b61c6ab5f...  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  NVML  |
|  risc0  |  v1.2.2  |  ❓ (\*)  | gfx1030: ❓ (\*) |   Dependent project tries to return carry-bit. Fixable.  |  |
|  rodinia\_suite  |    |  ❓ (\*)  | gfx90a: ❓ (\*) |   |  |
|  stdgpu  |  563dc59d6d08df...  |  ❓ (\*)  | gfx900: ❓ (\*) |   Multigpu/crash tests are flaky  |  |
|  TCLB  |  v6.7  |  ❓ (\*)  | gfx1030: ❓ (\*) |   |  |
|  thrust  |  756c5af  |  ❓ (\*)  | gfx900: ❓ (\*) |   Old. Should add `cccl`!  |  |
|  timemachine  |  01f14f8  |  ❓ (\*)  | gfx1030: ❓ (\*) |   Buildsystem nonsense  |  |
|  UppASD  |  gpu_new  |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  vllm  |  v0.6.3  |  ❓ (\*)  | gfx1030: ❓ (\*) |   Needs Pytorch  |  |
|  whispercpp  |    |  ❓ (\*)  | gfx1201: ❓ (\*) |   |  |
|  xgboost  |  v2.1.0  |  ❓ (\*)  | gfx900: ❓ (\*) |   |  |

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ➖ Conflicting statuses, see notes for different architectures
* ✅ (\*) Validation skipped, last known status was Valid
* ❌ (\*) Validation skipped, last known status was Invalid
* ❓ (\*) Validation skipped, no previous validation state to reference


> \* The following program tests were skipped for SCALE:\ master\ <408e2f7e>, and given states are from the last version they were tested on instead:
> 
> * FLAMEGPU2
> * whisper.cpp
> * FastEddy
> * bitnet
> * nvflip
> * UppASD
> * TCLB
> * FastEddy
> * TCLB
> * stdgpu
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
> * caffe
> * UppASD
> * caffe
> * hashcat
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
> * whisper.cpp
> * ggml
> * GROMACS
> * cuSZ
> * bitnet
> * nvflip
> * UppASD
> * hashcat
> * rodinia
> * caffe
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
> * cuSZ
> * bitnet
> * nvflip
> * rodinia
> * stdgpu
> * gomc
> * faiss
> * cycles
> * alien
> * GPUJPEG
> * ctranslate2
> * jitify
> * TCLB
> * ggml
> * GROMACS
> * cuSZ
> * caffe
> * risc0
> * timemachine
> * vllm
> * PhysX
> * PhysX
> * risc0
> * GooFit
> * hashinator
> * MAGMA
> * opencv
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
