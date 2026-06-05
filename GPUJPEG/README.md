# GPUJPEG

GPUJPEG is a high-performance GPU-accelerated JPEG codec from CESNET. It encodes and decodes JPEG
images on the GPU using CUDA, achieving substantially higher throughput than CPU-only codecs for
large or high-volume images. With SCALE, GPUJPEG's CUDA path runs on AMD GPUs with no source
changes, validated against the full `ctest` suite.

## Quick Start with Docker

Build GPUJPEG with SCALE in a single `docker build`. Pass `--build-arg GPU_ARCH=<your-gfx>` to
target a different AMD GPU (e.g. `gfx942`, `gfx1201`).

[Dockerfile](./Dockerfile)

## Try it locally

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t gpujpeg:scale -f GPUJPEG/Dockerfile .

# Print help (no GPU required):
docker run --rm gpujpeg:scale --help

# Encode a PPM image to JPEG on your AMD GPU:
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" \
  gpujpeg:scale --encode --input /work/input.ppm --output /work/output.jpg

# Decode the JPEG back to PPM:
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" \
  gpujpeg:scale --decode --input /work/output.jpg --output /work/decoded.ppm

# Quick round-trip smoke test with a generated image:
# docker run --rm --device /dev/dri --device /dev/kfd \
#   -v "$PWD:/work" \
#   gpujpeg:scale --encode --input /work/photo.png --output /work/photo_gpu.jpg \
#   --quality 90
```

## Build from source

[00-clone.sh](./00-clone.sh)

[01-patch.sh](./01-patch.sh)

[02-build.sh](./02-build.sh)

See the [SCALE installation guide](https://docs.scale-lang.com/stable/manual/tutorials/how-to-install/)
for instructions on getting SCALE on your system.

## Notes

- Validated against commit `3e045d1` (see `versions.txt`).
- One patch (`ld.patch`) is applied to fix a linker compatibility issue.
- The CI correctness test runs the full `ctest` suite, which covers encode and decode correctness
  across several image sizes and quality levels.
- The `libgpujpeg` shared library is bundled in the image and resolved automatically via
  `LD_LIBRARY_PATH`.
- GPUJPEG supports JPEG encoding only; other formats (PNG, PPM input) are handled by a thin
  conversion wrapper in the CLI.
