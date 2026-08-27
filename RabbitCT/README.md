# RabbitCT

RabbitCT is a cone-beam CT backprojection benchmark built around a real clinical C-arm CT
dataset of a rabbit. Backprojection is the bottleneck of most reconstruction pipelines, and
RabbitCT provides an open platform for comparing implementations across architectures on
identical input data, at problem sizes of 128, 256, 512, or 1024 voxels. This build uses
LolaCUDA, the naive CUDA reconstruction kernel. With SCALE, LolaCUDA runs on AMD GPUs with no
source changes.

## Try it locally

Pull the prebuilt SCALE image and reconstruct the bundled sample dataset on your AMD GPU, with
the result verified against a bundled reference volume, no build step required.

```bash
docker pull docker.io/spectralcompute/rabbitct:latest

# Reconstruct the bundled sample dataset at 1024^3 and verify against the bundled reference:
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/rabbitct:latest
```

Also available on Quay as `quay.io/spectral-compute/rabbitct:latest`. If pull doesn't work for
your GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**Print help** (requires GPU device passthrough since `rabbitRunner-NVCC` initialises CUDA
unconditionally at startup, even just to print usage):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/rabbitct:latest -h
```

**Reconstruct at a smaller size** (faster, still verified against the bundled reference):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/rabbitct:latest \
  -i /build/RabbitCT/RabbitCT/RabbitInput/RabbitInput.rct -m LolaCUDA -s 256
```

**Write the reconstructed volume out** (mount a host directory at `/work`):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" docker.io/spectralcompute/rabbitct:latest \
  -i /build/RabbitCT/RabbitCT/RabbitInput/RabbitInput.rct -m LolaCUDA -s 1024 \
  -o /work/reconstructed.vol
```

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs, no drift between what you
build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t rabbitct:scale -f RabbitCT/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `rabbitct:scale` for the pulled tag in any example above.

**Run the correctness test directly** (the same check the container's `test` stage runs in CI,
`02-test-run.sh`'s reference-volume comparison via `-c`):

```bash
docker build --target test -t rabbitct:test --build-arg GPU_ARCH=gfx1100 -f RabbitCT/Dockerfile .
docker run --rm --device /dev/dri --device /dev/kfd rabbitct:test
```

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/RabbitCT/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

[Dockerfile](./Dockerfile)

</details>

## Notes

- This is the actively maintained `spectral-compute/RabbitCT` fork (via `HPC-Dwarfs/RabbitCT` and
  `ipatix/RabbitCT`), a modern MIT-licensed reimplementation of the benchmark, not the original
  registration-gated codebase from the rabbitct.com competition. Check provenance against the
  `upstream_repo` in `project.json` if you're evaluating licensing terms.
- The bundled `RabbitInput/` dataset (~2.9 GB) is downloaded during the build from the upstream
  RabbitCT host and baked into this image, so the runtime image is large but self-contained.
- `-c <reference.vol>` makes the binary compare its reconstructed output against a known-good
  reference volume and exit non-zero on mismatch; this is what the container's `test` stage
  checks. `-o` writes the reconstructed volume out; `-p` writes the middle axial slice as a PGM.
- Several other algorithm variants (LolaBunny, LolaOMP, LolaOPT, LolaASM, LolaISPC) exist upstream
  for CPU comparison but are not built here; only LolaCUDA is exercised.
