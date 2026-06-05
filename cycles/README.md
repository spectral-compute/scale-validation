# Blender Cycles

Blender Cycles is the production path-tracing renderer that ships with Blender. It simulates
physically accurate light transport — global illumination, subsurface scattering, volumetrics — and
supports GPU-accelerated rendering via CUDA. With SCALE, Cycles runs its full CUDA render path on
AMD GPUs with no code changes, validated against the standalone `cycles` binary that Blender itself
packages.

## Quick Start with Docker

Build Blender Cycles with SCALE in a single `docker build`. Pass
`--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).

> **Note:** Cycles is a large build (~5–10 min depending on your machine and GPU arch).

[Dockerfile](./Dockerfile)

## Try it locally

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t cycles:scale -f cycles/Dockerfile .

# Print help (no GPU required):
docker run --rm cycles:scale --help

# Render the bundled monkey scene on your AMD GPU and save to host:
mkdir -p output
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD/output:/work" \
  cycles:scale \
  /build/cycles/cycles/examples/scene_monkey.xml \
  --device CUDA --output /work/monkey.png
# Output: /work/monkey.png  (a rendered image of Suzanne)

# Render on CPU only (no GPU needed — slower, for comparison):
docker run --rm \
  -v "$PWD/output:/work" \
  cycles:scale \
  /build/cycles/cycles/examples/scene_monkey.xml \
  --device CPU --output /work/monkey_cpu.png

# Render a different bundled scene:
# scene_cube_surface.xml  scene_cube_volume.xml  scene_sphere_bump.xml
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD/output:/work" \
  cycles:scale \
  /build/cycles/cycles/examples/scene_cube_surface.xml \
  --device CUDA --output /work/cube.png
```

## Build from source

[00-clone.sh](./00-clone.sh)

[01-patch.sh](./01-patch.sh)

[02-build.sh](./02-build.sh)

See the [SCALE installation guide](https://docs.scale-lang.com/stable/manual/tutorials/how-to-install/)
for instructions on getting SCALE on your system.

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
