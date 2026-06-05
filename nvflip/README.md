# NVIDIA FLIP

FLIP is a perceptual image-difference evaluator from NVIDIA Research. It computes a
human-vision-based error metric between a reference and a test image — LDR-FLIP for 8-bit PNG,
HDR-FLIP (multi-exposure tone-mapped) for EXR — commonly used to validate rendering algorithms
against a ground-truth reference. With SCALE, FLIP's CUDA kernel runs on AMD GPUs with no source
changes.

## Try it locally

Pull the prebuilt SCALE image and compare the bundled sample images on your AMD GPU — no build
step required.

```bash
docker pull docker.io/spectralcompute/nvflip:latest

# Compare the bundled sample images on your AMD GPU (LDR/PNG path):
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/nvflip:latest \
  -r /build/nvflip/images/reference.png -t /build/nvflip/images/test.png -v 1
```

Also available on Quay as `quay.io/spectral-compute/nvflip:latest`. If pull doesn't work for your
GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**Print help** (requires GPU device passthrough — `flip-cuda` initialises CUDA unconditionally at
startup, even just to print usage):

```bash
docker run --rm --device /dev/dri --device /dev/kfd docker.io/spectralcompute/nvflip:latest --help
```

**Compare in HDR mode** (EXR path, multi-exposure tone-mapping):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/nvflip:latest \
  -r /build/nvflip/images/reference.exr -t /build/nvflip/images/test.exr -v 1
```

**Compare your own images** (mount a host directory):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" \
  docker.io/spectralcompute/nvflip:latest \
  -r /work/reference.png -t /work/test.png -v 1
```

**Automated pass/fail** — exit nonzero if the mean FLIP error exceeds a threshold:

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/nvflip:latest \
  -r /build/nvflip/images/reference.png -t /build/nvflip/images/test.png \
  -v 1 --exit-on-test --exit-test-parameters mean 0.5
echo "exit: $?"
```

**Run the CPU binary directly**, for comparison against the GPU path:

```bash
docker run --rm --entrypoint flip docker.io/spectralcompute/nvflip:latest \
  -r /build/nvflip/images/reference.png -t /build/nvflip/images/test.png -v 1
```

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs — no drift between what you
build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t nvflip:scale -f nvflip/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `nvflip:scale` for the pulled tag in any example above.

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/nvflip/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

[Dockerfile](./Dockerfile)

</details>

## Notes

- Validated against commit `1eb247c` (see `versions.txt`). No patches are applied.
- The build produces two binaries: `flip` (CPU) and `flip-cuda` (GPU). The container's default
  entrypoint runs `flip-cuda`; the CPU binary is reachable via `--entrypoint flip`.
- Input format determines the mode: `.png` selects LDR-FLIP, `.exr` selects HDR-FLIP.
- `--exit-on-test --exit-test-parameters {mean|weighted-median|max} THRESHOLD` makes the tool exit
  non-zero when the chosen statistic exceeds the threshold — without it, the tool always exits 0
  regardless of how large the measured error is.
- `cudaSetDevice(0)` is hardcoded in FLIP, so it always targets the first visible GPU.
- The CI correctness test runs `flip` and `flip-cuda` on the same reference/test pair and checks
  that the CPU and GPU error maps agree (ImageMagick MSE < 0.01).
