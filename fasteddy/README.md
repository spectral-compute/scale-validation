# FastEddy

FastEddy is NCAR/NOAA's GPU-accelerated large-eddy-simulation (LES) model for atmospheric
boundary-layer and complex-terrain weather research. Its numerical core is written directly in
CUDA and it scales across multiple GPUs via MPI. With SCALE, that CUDA core runs on AMD GPUs
without modification.

## Try it locally

Pull the prebuilt SCALE image. FastEddy needs a `.in` parameter file to actually run a case, so
running it with no arguments just prints its usage message and exits (no GPU required for that).

```bash
docker pull docker.io/spectralcompute/fasteddy:latest

docker run --rm docker.io/spectralcompute/fasteddy:latest
# usage: FastEddy paramFile
```

To run a real case, mount a directory containing a FastEddy `.in` config at `/work` (requires an
AMD GPU). Example configs ship in the upstream repository's `tutorials/examples/` directory (e.g.
`Example01_NBL.in`, the same case the container's own test stage runs against reference output):

```bash
git clone --depth 1 --branch v2.0.0 https://github.com/NCAR/FastEddy-model.git
cd FastEddy-model/tutorials/examples
mkdir -p output   # FastEddy writes its output relative to the current directory

docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" -w /work \
  docker.io/spectralcompute/fasteddy:latest Example01_NBL.in
```

Set `-e NP=<n>` to run with more than one MPI process (the config's own `numProcsX`/`numProcsY`
etc. need to agree with however many you pick):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -e NP=4 -v "$PWD:/work" -w /work \
  docker.io/spectralcompute/fasteddy:latest Example01_NBL.in
```

Also available on Quay as `quay.io/spectral-compute/fasteddy:latest`. If pull doesn't work for
your GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs (both FastEddy's own and its
OpenMPI dependency's) -- no drift between what you build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t fasteddy:scale -f fasteddy/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `fasteddy:scale` for the pulled tag in any example above.

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/fasteddy/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/`, `versions.txt`,
and the sibling `openmpi/` project's scripts from the repository root, so build it from there (as
shown above).

[Dockerfile](./Dockerfile)

### Run the same benchmark CI runs

The `test` stage runs a real simulation (`Example01_NBL`, shrunk to a size that fits on smaller
GPUs), renders diagnostic plots from it via a Jupyter notebook, and compares each plot's MSE
against checked-in reference images, failing if any comparison exceeds its threshold:

```bash
docker build --target test -t fasteddy:test --build-arg GPU_ARCH=gfx1100 -f fasteddy/Dockerfile .
docker run --rm --device /dev/dri --device /dev/kfd fasteddy:test
```

</details>

## Notes

- OpenMPI is built from source and bundled into the image (`/build/openmpi/install`, configured
  with CUDA-aware support -- `--with-cuda`, `OMPI_MCA_accelerator=cuda`), so `mpirun` and the MPI
  runtime are already present. You don't need MPI installed on the host to run this image.
- FastEddy reads/writes relative to its current directory, hence `-w /work` alongside `-v
  "$PWD:/work"` in the examples above; some configs (like `Example01_NBL.in`) expect an `output/`
  subdirectory to already exist.
- Known issue: on `gfx900` and `gfx90a`, running FastEddy under SCALE currently fails (tracked
  upstream at `spectral-compute/scale#1217`); other AMD architectures are unaffected.
