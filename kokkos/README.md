# WIP: Integrating Kokkos to scale-val

## Kokkos TLDR, relationship w/ scale
Kokkos allows to write one C++ source code that can be compiled and run on CPU and GPUs from both Nvidia and AMD, by the mean of activating the serial/cuda/hip backend at configure time. Adding it to `scale-validation` has 3 interests imo:

- Coverage of the wide cuda API used in Kokkos's CUDA backend
- Benchmarking:
  - on AMD GPU: HIP vs CUDA+scale backend
  - on Nvidia GPU: scale's clang/nvcc vs clang / nvcc.
- Good impression on the HPC community that uses Kokkos a lot :-) 

### Compiling Kokkos for Nvidia GPU, two possible compilers

Classicaly, Kokkos can be compiled for Nvidia GPUs using the following cmake command that selects the CUDA backend, and the target GPU. Find all the backends [here](https://kokkos.org/kokkos-core-wiki/get-started/configuration-guide.html#architectures).

```bash
cmake \
    -DKokkos_ENABLE_CUDA=ON \
    -DKokkos_ARCH_ADA89=ON \
```

Then, either llvm's `clang` or `nvcc` can be used to compile. If the user chooses `nvcc`, it is recommended to used kokkos's [`nvcc_wrapper`](https://github.com/kokkos/kokkos/blob/develop/bin/nvcc_wrapper) that helps dispatching correctly the host/device flags (among other things). 

```
-DCMAKE_CXX_COMPILER=clang++
#or
-DCMAKE_CXX_COMPILER=/path_to_kokkos/bin/nvcc_wrapper
```

## Current issues with Kokkos/scale/clang

- `clang-20/21` and `scale-clang-20` fail to build Kokkos in Release mode. The issue stems from `llvm's clang`, and the strategy for Kokkos is currently discussed [in this PR](https://github.com/kokkos/kokkos/pull/8984)
- Several kokkos patches are needed to use scale (why I clone my fork of kokkos in `00-clone.sh` and not the official repo):
  - For now, getting the commits from the PR so that we can build in Release
  - Ensure that nvcc_wrapper picks nvcc from scale and not from PATH: [commit](https://github.com/rbourgeois33/kokkos/commit/aa8a78ed4fac666ac2c85c0099905399f989a83f)
  - Hide `__half` stuff that causes compile issues: [commit](https://github.com/rbourgeois33/kokkos/commit/f4ba34230688d8aa58790648c25d54ee5ca38bec)
  - Comment out CUDA Graph API calls that are not supported by scale: [commit](https://github.com/rbourgeois33/kokkos/commit/d749011c26ade448c6a77d2029a7bcd76675411f)
- - -fuse-ldd ?

## Build status

|  | Nvidia (`sm_89`) | AMD (`gfx1100`) |
|---|---|---|
| scale's `clang` | | |
| scale's `nvcc` |  | |

## Tests status
|  | Nvidia (`sm_89`) | AMD (`gfx1100`) |
|---|---|---|
| llvm's `clang-20` | 5, 13  | N.A | |
| nvidia's `nvcc` | 5, 13| N.A|
| scale's `clang` | | |
| scale's `nvcc` |  | |

- Tests 5 and 13 fail for non scale build because CUDA graph calls are commented out, so this is success for now