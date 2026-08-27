# cuSZ

cuSZ is a GPU implementation of the SZ error-bounded lossy compressor for scientific data. It
compresses arrays of `float`/`double` values (simulation output, sensor grids, etc.) while
guaranteeing every reconstructed value stays within a user-specified error bound, using CUDA to
accelerate prediction, quantization, and Huffman coding. With SCALE, cuSZ's CUDA kernels run on
AMD GPUs.

## Try it locally

Pull the prebuilt SCALE image and run a compress/decompress round trip on a synthetic float
array (no GPU-specific dataset required, just an AMD GPU to run on).

```bash
docker pull docker.io/spectralcompute/cusz:latest

# Make a small synthetic 100x100 float32 array to compress, then compress and
# decompress it, checking the reconstruction error against the original:
python3 -c "import numpy as np; np.random.rand(100, 100).astype('float32').tofile('data.f32')"

docker run --rm --device /dev/dri --device /dev/kfd -v "$PWD:/work" \
  docker.io/spectralcompute/cusz:latest \
  -t f32 -m abs -e 1e-3 -i /work/data.f32 -l 100x100 -z

docker run --rm --device /dev/dri --device /dev/kfd -v "$PWD:/work" \
  docker.io/spectralcompute/cusz:latest \
  -i /work/data.f32.cusza -x --compare /work/data.f32
```

The first command compresses `data.f32` to `data.f32.cusza` with an absolute error bound of
`1e-3`. The second decompresses it and, via `--compare`, prints quality metrics (max error,
PSNR, etc.) against the original file.

Also available on Quay as `quay.io/spectral-compute/cusz:latest`. If pull doesn't work for your
GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**List available cusz options** (no GPU required):

```bash
docker run --rm docker.io/spectralcompute/cusz:latest --help
```

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs, so there is no drift between
what you build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t cusz:scale -f cuSZ/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `cusz:scale` for the pulled tag in any example above.

To run the same correctness suite CI runs (a set of unit-test binaries under `build/test`,
covering the core compression kernels):

```bash
docker build --target test -t cusz:test --build-arg GPU_ARCH=gfx1100 -f cuSZ/Dockerfile .
docker run --rm --device /dev/dri --device /dev/kfd cusz:test
```

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/cuSZ/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

[Dockerfile](./Dockerfile)

</details>

## Notes

- The error bound is a hard guarantee, not a target: every reconstructed value is within `eb` of
  the original under the chosen mode (`abs` for an absolute bound, `rel`/`r2r` for a bound
  relative to the data's value range).
- Only `f32` and `f64` input arrays are supported; `-l`/`--len` takes the array dimensions
  fastest-varying first (e.g. `-l 3600x1800` for a 1800-row, 3600-column array).
- `-z`/`--compress` and `-x`/`--decompress` are mutually exclusive; the compressed output is
  always written next to the input as `<input>.cusza`.
