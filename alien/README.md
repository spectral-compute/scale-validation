# ALIEN

ALIEN (Artificial LIfe ENvironment) is an artificial life simulation tool built on a specialized
2D particle physics engine written in CUDA. Simulated bodies are networks of particles that can be
upgraded with higher-level functions (sensors, muscles, neurons, constructors, etc.), acting as
digital organisms that evolve via mutation and natural selection. Upstream, ALIEN is primarily an
interactive desktop application (Dear ImGui + OpenGL) for exploring simulations visually; this
suite additionally builds and validates its headless `cli` runner and the engine core's own
GoogleTest suites (`EngineTests`, `NetworkTests`). With SCALE, that CUDA simulation engine runs on
AMD GPUs without modification.

## Try it locally

Pull the prebuilt SCALE image and run a real simulation on your AMD GPU using ALIEN's own headless
`cli` tool and a bundled sample simulation, no display and no build step required.

```bash
docker pull docker.io/spectralcompute/alien:latest

# Run 1000 timesteps of the bundled sample simulation on your AMD GPU:
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/alien:latest
```

This loads the bundled `autosave.sim` sample, runs it for 1000 timesteps entirely on the GPU, and
prints the detected GPU name and the achieved timesteps-per-second (actual numbers depend on your
GPU), in this shape:

```
Reading input
Device: <your GPU>
Start simulation
Simulation finished: 1,000 time steps, <N> ms, <TPS> TPS
Writing output
Finished
```

Also available on Quay as `quay.io/spectral-compute/alien:latest`. If pull doesn't work for your
GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**Print help** (no GPU required: `cli --help` returns before touching CUDA):

```bash
docker run --rm docker.io/spectralcompute/alien:latest --help
```

**Run more timesteps, and keep the output simulation file** (mount a host directory):

```bash
docker run --rm --device /dev/dri --device /dev/kfd -v "$PWD:/work" \
  docker.io/spectralcompute/alien:latest \
  -i /build/alien/resources/autosave.sim -o /work/out.sim -t 10000
```

**Run against your own simulation file** (mount it in, `-i` needs a matching
`<name>.settings.json` alongside it, same convention as the bundled sample):

```bash
docker run --rm --device /dev/dri --device /dev/kfd -v "$PWD:/work" \
  docker.io/spectralcompute/alien:latest \
  -i /work/mysim.sim -o /work/mysim-out.sim -t 5000
```

**Run the engine's own validation suite** instead of the CLI demo (real GoogleTest binaries
against the simulation engine core, the same ones CI runs):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  --entrypoint EngineTests docker.io/spectralcompute/alien:latest
docker run --rm --device /dev/dri --device /dev/kfd \
  --entrypoint NetworkTests docker.io/spectralcompute/alien:latest
```

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs, so there's no drift between
what you build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t alien:scale -f alien/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `alien:scale` for the pulled tag in any example above.

To build and run just the `test` stage (what CI actually runs):

```bash
docker build --target test -t alien:test --build-arg GPU_ARCH=gfx1100 -f alien/Dockerfile .
docker run --rm --device /dev/dri --device /dev/kfd alien:test
```

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/alien/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

[Dockerfile](./Dockerfile)

</details>

## Notes

- `patches/0001-remove-dyn-parallelism.patch` comments out the one CUDA kernel in
  `SimulationKernels.cu` that uses dynamic parallelism (a kernel launching a nested kernel);
  upstream notes this costs about 20% performance, but it works around a build-time limitation
  with this kernel launch style.
- ALIEN's own `CMakeLists.txt` fetches and builds its C++ dependencies via vcpkg, vendored as a
  submodule in the upstream repo, so no separate install step is needed in this Dockerfile.
- Upstream builds 4 executables: the interactive `alien` GUI, the headless `cli` runner, and
  `EngineTests`/`NetworkTests`. Only `cli` and the two test binaries are shipped in the container;
  the GUI needs a window/display and is out of scope for this suite.
- `cli -i <sim> -o <out> -t <timesteps>` loads a saved simulation, runs it headlessly for the
  given number of timesteps on the GPU, and writes the result back out; it reads `<sim>` with its
  extension swapped for `.settings.json` from the same directory, so keep the two files together.
- `EngineTests` excludes `DataTransferTests.largeData` and
  `MutationTests.insertMutation_emptyGenome`, matching `03-test.sh` exactly.
