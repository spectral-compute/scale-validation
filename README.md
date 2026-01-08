# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for 46405500:\ master\ <df45e576>.**

Test scripts get added to this repository long before they are fully
supported by SCALE. We use the outcome of this kind of testing to prioritise
development. Contributions welcome!

This table summarises the current state as of the most recent stable release
of SCALE. "Needs" describes missing CUDA APIs/features that the project
definitely needs. The list may not be exhaustive.

| Project | Version | Status | Valid GFX | Notes | Needs |
|---|---|---|---|---|---|
|  Alien  |  scaletest  |  ✅  | gfx90a: ✅ |   Needs patch to remove OpenGL interop  |  OpenGL Interop  |
|  AMGX  |  v2.4.0  |  ➖ (\*)  | gfx90a: ✅, gfx1030: ❌, gfx1201: ❓ (\*\*), gfx1100: ❓ (\*\*) |   |  |
|  arrayfire  |  v3.9.0  |    |  |   |  cuDNN, more cuSPARSE  |
|  caffe  |  9b891540183ddc...  |    |  |   |  |
|  ctranslate2  |  v4.5.0  |  ✅  | gfx90a: ✅ |   Some intermittent test failures  |  |
|  cuml  |  b17f2db  |    |  |   Buildsystem nonsnse  |  |
|  cuSZ  |  v0.16.2  |  ✅  | gfx90a: ✅ |   |  |
|  CUTLASS  |  v4.1.0  |  ➖ (\*)  | gfx90a: ✅, gfx1030: ❌, gfx900: ❌, gfx1100: ❌, gfx1201: ❓ (\*\*) |   |  |
|  CV-CUDA  |  f769fe4  |    |  |   |  |
|  cycles  |  v4.4.0  |  ✅  | gfx90a: ✅ |   |  |
|  faiss  |  v1.9.0  |  ❌  | gfx90a: ❌ |   |  |
|  FastEddy  |  v2.0.0  |  ✅  | gfx90a: ✅ |   |  |
|  FLAMEGPU2  |  v2.0.0-rc.2  |  ➖ (\*)  | gfx1030: ✅, gfx90a: ❌, gfx1201: ❌, gfx1100: ❌ |   |  |
|  gomc  |  4c12477  |  ✅  | gfx90a: ✅ |   |  |
|  GooFit  |  v2.3.0  |    |  |   |  Texture Refs  |
|  gpu\_jpeg2k  |  ee715e9  |  ✅  | gfx90a: ✅ |   |  |
|  GROMACS  |  v2025.1  |  ✅  | gfx90a: ✅ |   |  |
|  ggml  |  d3a58b0  |  ✅  | gfx90a: ✅ |   Old version works. New version needs more APIs  |  Missing async opcodes  |
|  hashcat  |  6716447dfce969...  |  ✅  | gfx90a: ✅ |   |  |
|  hashinator  |  34cf188  |    |  |   |  |
|  hypre  |  v2.33.0  |  ➖ (\*)  | gfx90a: ❌, gfx1201: ❓ (\*\*), gfx1100: ❓ (\*\*) |   Buildsystem nonsense  |  |
|  jitify  |  master  |  ➖ (\*)  | gfx90a: ✅, gfx1201: ❌ |   Some test failures  |  |
|  llama.cpp  |    |  ➖ (\*)  | gfx90a: ❌, gfx1201: ❓ (\*\*), gfx1100: ❓ (\*\*) |   Old version works. New version needs more APIs  |  More graph APIs, async matmuls  |
|  llm.c  |  7ecd8906afe6ed...  |  ➖ (\*)  | gfx90a: ❌, gfx1201: ❓ (\*\*), gfx1100: ❓ (\*\*) |   Old version builds+runs. New version needs more APIs  |  NVML, cuBLASLt  |
|  MAGMA  |  v2.9.0  |    |  |   |  |
|  nvflip  |  1eb247c  |  ✅  | gfx90a: ✅ |   |  |
|  OpenCV  |  725e440  |    |  |   |  NPP  |
|  openmpi  |  v4.1  |    |  |   |  |
|  PhysX  |    |    |  |   Numerous missing APIs  |  PTX barriers, cudaArray, graphics interop  |
|  pytorch  |  v1.8.1  |  ➖ (\*)  | gfx90a: ❌, gfx1201: ❓ (\*\*), gfx1100: ❓ (\*\*) |   Numerous missing APIs  |  cuDNN, barriers, async copy, wgmma, more cuSPARSE, mempools, cublasLt,...  |
|  quda  |  07822b61c6ab5f...  |  ➖ (\*)  | gfx90a: ❌, gfx1201: ❓ (\*\*), gfx1100: ❓ (\*\*) |   |  NVML  |
|  risc0  |  v1.2.2  |    |  |   Dependent project tries to return carry-bit. Fixable.  |  |
|  rodinia\_suite  |    |  ✅  | gfx90a: ✅ |   |  |
|  stdgpu  |  563dc59d6d08df...  |  ❓ (\*\*)  | gfx90a: ❓ (\*\*) |   Multigpu/crash tests are flaky  |  |
|  TCLB  |  v6.7  |  ✅  | gfx90a: ✅ |   |  |
|  thrust  |  756c5af  |  ➖ (\*)  | gfx90a: ❌, gfx1201: ❓ (\*\*), gfx1100: ❓ (\*\*) |   Old. Should add `cccl`!  |  |
|  timemachine  |  01f14f8  |    |  |   Buildsystem nonsense  |  |
|  UppASD  |  gpu_new  |    |  |   |  |
|  vllm  |  v0.6.3  |    |  |   Needs Pytorch  |  |
|  whispercpp  |    |  ✅  | gfx90a: ✅ |   |  |
|  xgboost  |  v2.1.0  |  ➖ (\*)  | gfx90a: ❌, gfx1201: ❓ (\*\*), gfx1100: ❓ (\*\*) |   |  |

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ➖ (\*) Conflicting statuses, see notes for different architectures
* ✅ (\*\*) Validation skipped, last known status was Valid
* ❌ (\*\*) Validation skipped, last known status was Inalid
* ❓ (\*\*) Validation skipped, no previous validation state to reference

> \* Notes: 
> * FLAMEGPU2
>	* Program had conflicting states for different architectures:
>	 * gfx1030 : ❌
>	 * gfx90a : ❌
>	 * gfx1201 : ❌
>	 * gfx1100 : ❌
> * jitify
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❌
>	 * gfx1201 : ❌
> * CUTLASS
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❌
>	 * gfx1030 : ❌
>	 * gfx900 : ❌
>	 * gfx1100 : ❌
>	 * gfx1201 : ❓ (\*\*)
> * AMGX
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❌
>	 * gfx1030 : ❌
>	 * gfx1201 : ❓ (\*\*)
>	 * gfx1100 : ❓ (\*\*)
> * thrust
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❓ (\*\*)
>	 * gfx1201 : ❓ (\*\*)
>	 * gfx1100 : ❓ (\*\*)
> * pytorch
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❓ (\*\*)
>	 * gfx1201 : ❓ (\*\*)
>	 * gfx1100 : ❓ (\*\*)
> * hypre
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❓ (\*\*)
>	 * gfx1201 : ❓ (\*\*)
>	 * gfx1100 : ❓ (\*\*)
> * quda
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❓ (\*\*)
>	 * gfx1201 : ❓ (\*\*)
>	 * gfx1100 : ❓ (\*\*)
> * llm.c
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❓ (\*\*)
>	 * gfx1201 : ❓ (\*\*)
>	 * gfx1100 : ❓ (\*\*)
> * llama-cpp
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❓ (\*\*)
>	 * gfx1201 : ❓ (\*\*)
>	 * gfx1100 : ❓ (\*\*)
> * xgboost
>	* Program had conflicting states for different architectures:
>	 * gfx90a : ❓ (\*\*)
>	 * gfx1201 : ❓ (\*\*)
>	 * gfx1100 : ❓ (\*\*)


> \*\* The following program tests were skipped for 46405500:\ master\ <df45e576>, and given states are from the last version they were tested on instead:
> 
> * stdgpu
> * CUTLASS
> * stdgpu
> * stdgpu
> * stdgpu
> * stdgpu
> * AMGX
> * thrust
> * pytorch
> * hypre
> * quda
> * llm.c
> * llama-cpp
> * xgboost
> * AMGX
> * thrust
> * pytorch
> * hypre
> * quda
> * llm.c
> * llama-cpp
> * xgboost

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
