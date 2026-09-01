# GPUJPEG

GPUJPEG is a CUDA-accelerated JPEG encoder and decoder from CESNET. It offloads JPEG
compression and decompression to the GPU for high-throughput image processing, and ships both a
`gpujpegtool` command-line utility and a C library (`libgpujpeg`). With SCALE, GPUJPEG's CUDA
kernels run on AMD GPUs without modification.

## Try it locally

Pull the prebuilt SCALE image and encode/decode a sample image on your AMD GPU.

```bash
docker pull docker.io/spectralcompute/gpujpeg:latest

# Generate a small synthetic input image (needs ImageMagick's `convert` on the host):
convert -size 256x256 -depth 8 gradient:blue-red input.ppm

# Encode it on your AMD GPU:
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" docker.io/spectralcompute/gpujpeg:latest \
  --encode /work/input.ppm /work/output.jpg

# Decode it back:
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" docker.io/spectralcompute/gpujpeg:latest \
  --decode /work/output.jpg /work/decoded.ppm
```

Also available on Quay as `quay.io/spectral-compute/gpujpeg:latest`. If pull doesn't work for your
GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**List available options** (no GPU required):

```bash
docker run --rm docker.io/spectralcompute/gpujpeg:latest --help
```

**Encode at a specific quality and chroma subsampling** (mount your own image at `/work`):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" docker.io/spectralcompute/gpujpeg:latest \
  --encode --quality 90 --subsampled=4:4:4 /work/input.ppm /work/output.jpg
```

**Print JPEG file info**:

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" docker.io/spectralcompute/gpujpeg:latest \
  --info /work/output.jpg
```

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs, so there's no drift between
what you build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t gpujpeg:scale -f gpujpeg/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `gpujpeg:scale` for the pulled tag in any example above.

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/gpujpeg/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

To run the same correctness checks CI runs, including the test stage:

```bash
docker build --target test -t gpujpeg:test --build-arg GPU_ARCH=gfx1100 -f gpujpeg/Dockerfile .
docker run --rm --device /dev/dri --device /dev/kfd gpujpeg:test
```

[Dockerfile](./Dockerfile)

</details>

## Notes

- `04-test-claims.sh` is an image-fidelity check, not just a smoke test: it round-trips a
  synthetic image through encode/decode and computes PSNR (peak signal-to-noise ratio) between the
  original and decoded PPM/PGM output, failing if fidelity drops below a threshold (30 dB for
  standard round-trips, 40 dB at quality 100). It also cross-checks interop with a standard decoder
  (ImageMagick), quality-vs-file-size ordering, and every colorspace/subsampling/pixel-format
  combination the tool supports.
- `ld.patch` fixes `test/unit/Makefile`, which overwrote `LD_LIBRARY_PATH` instead of extending it
  when running GPUJPEG's bundled unit test binary via `ctest`, dropping the CUDA runtime library
  path SCALE's environment sets, so the patch appends to the existing value instead.
- `02-build.sh` never runs `make install`, so `gpujpegtool` and `libgpujpeg.so` are copied straight
  out of `build/` rather than an `install/` prefix, with `LD_LIBRARY_PATH` extended accordingly so
  the tool can find the library.
