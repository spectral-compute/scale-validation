# Blender Cycles

Blender Cycles is the production path-tracing renderer that ships with Blender. It simulates
physically accurate light transport — global illumination, subsurface scattering, volumetrics — and
supports GPU-accelerated rendering via CUDA. With SCALE, Cycles runs its full CUDA render path on
AMD GPUs with no code changes, validated against the standalone `cycles` binary that Blender itself
packages.

## Try it locally

Pull the prebuilt SCALE image and render the bundled monkey scene on your AMD GPU — no build step
required.

```bash
docker pull docker.io/spectralcompute/cycles:latest

# Render the bundled monkey scene on your AMD GPU and save to host:
mkdir -p output
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD/output:/work" \
  docker.io/spectralcompute/cycles:latest \
  /build/cycles/cycles/examples/scene_monkey.xml \
  --device CUDA --output /work/monkey.png
# Output: /work/monkey.png  (a rendered image of Suzanne)
```

Also available on Quay as `quay.io/spectral-compute/cycles:latest`. If pull doesn't work for your
GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**Render on CPU only** (no GPU needed — slower, for comparison):

```bash
docker run --rm \
  -v "$PWD/output:/work" \
  docker.io/spectralcompute/cycles:latest \
  /build/cycles/cycles/examples/scene_monkey.xml \
  --device CPU --output /work/monkey_cpu.png
```

**Render a different bundled scene** (`scene_cube_surface.xml`, `scene_cube_volume.xml`,
`scene_sphere_bump.xml`):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD/output:/work" \
  docker.io/spectralcompute/cycles:latest \
  /build/cycles/cycles/examples/scene_cube_surface.xml \
  --device CUDA --output /work/cube.png
```

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs — no drift between what you
build and what CI validates. Cycles is a large build (~5–10 min depending on your machine and GPU
arch).

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t cycles:scale -f cycles/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `cycles:scale` for the pulled tag in any example above.

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/cycles/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

[Dockerfile](./Dockerfile)

</details>

## Notes

- Validated against Cycles `v4.4.0` (the standalone release, separate from full Blender).
- The build is configured with OpenColorIO enabled and many optional features disabled (USD,
  OSL, NanoVDB, OpenVDB, Alembic, Hydra) to keep the build lean and portable.
- Two patches are applied: `glog.patch` (compatibility with newer glog) and `intrinsics.patch`
  (fix a `ifndef(HIP)` guard that breaks CUDA compilation).
- `glog` is statically linked using a pre-compiled `libglog_ubuntu.a` so the runtime image has
  no glog dependency.
- The CI correctness test renders four example scenes on both CPU and CUDA and verifies that the
  per-pixel mean squared error is below 0.01.
- Scene files (`scene_*.xml`) are bundled in the image at `/build/cycles/cycles/examples/`.
