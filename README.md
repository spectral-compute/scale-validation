# Testing SCALE against 3rd-party projects

This repo contains the scripts used to clone, build, and test various
open-source projects to validate the correctness of [SCALE](https://docs.scale-lang.com/).

## Current Status

**This shows the test status for SCALE:\ master\ <bb9e9013>.**

Test scripts get added to this repository long before they are fully
supported by SCALE. We use the outcome of this kind of testing to prioritise
development. Contributions welcome!

This table summarises the current state as of the most recent stable release
of SCALE. "Needs" describes missing CUDA APIs/features that the project
definitely needs. The list may not be exhaustive.

| Project | Version | Status | Valid GFX |
|---|---|---|---|
|  Alien  |  scaletest  |  ➖  | gfx90a: ✅, gfx1030: ✅, gfx1100: ✅, gfx1201: ✅, gfx900: ❌ |
|  AMGX  |  v2.4.0  |  ✅  |  |
|  arrayfire  |  v3.9.0  |  ➖  | gfx900: ✅, gfx90a: ✅, gfx1201: ✅, gfx1100: ✅, gfx1030: ❌ |
|  caffe  |  9b891540183ddc...  |  ➖  | gfx90a: ✅, gfx1030: ✅, gfx1201: ✅, gfx1100: ✅, gfx900: ❌ |
|  ctranslate2  |  v4.5.0  |  ❌  |  |
|  cuml  |  b17f2db  |  ✅  |  |
|  cuSZ  |  v0.16.2  |  ➖  | gfx90a: ✅, gfx1100: ✅, gfx1201: ✅, gfx900: ❌, gfx1030: ❌ |
|  CUTLASS  |  v4.1.0  |  ❓ (\*)  |  |
|  CV-CUDA  |  f769fe4  |  ✅  |  |
|  cycles  |  v4.4.0  |  ❌  |  |
|  faiss  |  v1.9.0  |  ➖  | gfx900: ✅, gfx1030: ✅, gfx1100: ✅, gfx1201: ✅, gfx90a: ❌ |
|  FastEddy  |  v2.0.0  |  ➖  | gfx900: ✅, gfx90a: ❌, gfx1201: ❌, gfx1030: ❌, gfx1100: ❌ |
|  FLAMEGPU2  |  v2.0.0-rc.2  |  ➖  | gfx900: ✅, gfx1201: ✅, gfx1030: ✅, gfx90a: ❌, gfx1100: ❌ |
|  gomc  |  4c12477  |  ➖  | gfx900: ✅, gfx90a: ✅, gfx1100: ✅, gfx1201: ✅, gfx1030: ❌ |
|  GooFit  |  v2.3.0  |  ❌  |  |
|  gpu\_jpeg2k  |  ee715e9  |  ❌  |  |
|  GROMACS  |  v2025.4  |  ❓ (\*)  |  |
|  ggml  |  d3a58b0  |  ❌  |  |
|  hashcat  |  6716447dfce969...  |  ➖  | gfx90a: ✅, gfx1030: ✅, gfx1100: ✅, gfx1201: ✅, gfx900: ❌ |
|  hashinator  |  34cf188  |  ✅  |  |
|  hypre  |  v2.33.0  |  ❌  |  |
|  jitify  |  master  |  ➖  | gfx90a: ✅, gfx1100: ✅, gfx900: ❌, gfx1201: ❌, gfx1030: ❌ |
|  llama.cpp  |    |  ❓ (\*)  |  |
|  llm.c  |  7ecd8906afe6ed...  |  ✅  |  |
|  MAGMA  |  v2.9.0  |  ❌  |  |
|  nvflip  |  1eb247c  |  ➖  | gfx90a: ✅, gfx1100: ✅, gfx1201: ✅, gfx900: ❌, gfx1030: ❌ |
|  OpenCV  |  725e440  |  ➖  | gfx90a: ✅, gfx1030: ✅, gfx1100: ✅, gfx1201: ✅, gfx900: ❓ (\*) |
|  openmpi  |  v4.1  |  ✅  |  |
|  PhysX  |  1e44a0e  |  ✅  |  |
|  pytorch  |  v2.9.0-rc4  |  ➖  | gfx90a: ✅, gfx1201: ✅, gfx1100: ✅, gfx900: ✅, gfx1030: ❌ |
|  quda  |  07822b61c6ab5f...  |  ➖  | gfx900: ✅, gfx1201: ❌, gfx1100: ❌, gfx90a: ❌, gfx1030: ❌ |
|  risc0  |  v1.2.2  |  ✅  |  |
|  rodinia\_suite  |    |  ❓ (\*)  |  |
|  stdgpu  |  563dc59d6d08df...  |  ✅  |  |
|  TCLB  |  v6.7  |  ➖  | gfx90a: ✅, gfx1030: ✅, gfx1201: ✅, gfx900: ❌, gfx1100: ❌ |
|  thrust  |  756c5af  |  ✅  |  |
|  timemachine  |  01f14f8  |  ✅  |  |
|  UppASD  |  gpu_new  |  ❌  |  |
|  vllm  |  v0.6.3  |  ✅  |  |
|  whispercpp  |    |  ❓ (\*)  |  |
|  xgboost  |  v2.1.0  |  ✅  |  |

*Key:*
* ✅ Validated succesfully
* ❌ Failed to validate
* ➖ Conflicting statuses, see notes for different architectures
* ✅ (\*) Validation skipped, last known status was Valid
* ❌ (\*) Validation skipped, last known status was Invalid
* ❓ (\*) Validation skipped, no previous validation state to reference


> \* The following program tests were skipped for SCALE:\ master\ <bb9e9013>, and given states are from the last version they were tested on instead:
> 
> * `opencv` on `gfx900`

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
