# llama.cpp

llama.cpp is a C/C++ inference engine for large language models distributed in the GGUF format.
Built around the GGML tensor library, it targets efficient inference on everything from CPUs to
GPUs, with quantization support that lets large models run in a fraction of their native memory
footprint. With SCALE, llama.cpp's CUDA backend (`ggml-cuda`) runs on AMD GPUs.

## Try it locally

Pull the prebuilt SCALE image and verify it detects your AMD GPU -- no build step required.

```bash
docker pull docker.io/spectralcompute/llama.cpp:latest

# Verify GPU detection (requires an AMD GPU):
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/llama.cpp:latest --list-devices
```

Also available on Quay as `quay.io/spectral-compute/llama.cpp:latest`. If pull doesn't work for
your GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**List available llama-cli options** (no GPU required):

```bash
docker run --rm docker.io/spectralcompute/llama.cpp:latest --help
```

**Run inference against your own GGUF model** (mount it at `/work`):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" docker.io/spectralcompute/llama.cpp:latest \
  -m /work/model.gguf -p "The capital of France is" -n 32 -ngl 99
```

**Benchmark prompt/token throughput** (same tool `04-benchmark.sh` runs in CI, via
`--entrypoint`):

```bash
docker run --rm --device /dev/dri --device /dev/kfd --entrypoint llama-bench \
  -v "$PWD:/work" docker.io/spectralcompute/llama.cpp:latest -m /work/model.gguf
```

`llama-server` (OpenAI-compatible HTTP API) is also on `PATH`, reachable the same way via
`--entrypoint llama-server`.

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs -- no drift between what you
build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t llama.cpp:scale -f llama.cpp/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `llama.cpp:scale` for the pulled tag in any example above.

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/llama.cpp/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

To exercise the correctness/benchmark suite the same way CI does:

```bash
docker build --target test --build-arg GPU_ARCH=gfx1100 -t llama.cpp:test -f llama.cpp/Dockerfile .
docker run --rm --device /dev/dri --device /dev/kfd llama.cpp:test
```

[Dockerfile](./Dockerfile)

</details>

## Notes

- Validated against upstream build `b9522` (see `versions.txt`). Five patches are applied on top,
  each working around a specific gap in non-NVIDIA CUDA backend support:
  - `fp4-scale-decode` decodes MXFP4/NVFP4 block scales via the portable software path, so
    dequantized values match the CPU reference bit-for-bit on every target.
  - `fattn-shared-mem-fallback` falls back flash attention to the shared-memory-frugal tile kernel
    when an MMA config needs more shared memory than the device actually provides.
  - `fattn-divergent-barrier` fixes a flash attention barrier that diverging warps within a wider
    wave could reach an inconsistent number of times, leaving the block out of step.
  - `disable-cooperative-launch` reports cooperative launch as unsupported, forcing the
    single-block softmax reduction path instead.
  - `disable-cub` builds without NVIDIA's device-level CUB algorithms, falling back to
    llama.cpp's native kernels (as upstream already does for non-NVIDIA backends).
- The CI test suite runs upstream's own `ctest` GPU suite (`test-backend-ops`, `test-llama-archs`,
  etc.) with `GGML_CUDA_DISABLE_GRAPHS=1` and the `test-thread-safety` case skipped, working
  around two known issues; live-HuggingFace fixture tests are excluded since they diff against
  moving third-party uploads rather than a frozen snapshot.
- No model is bundled in the image -- GGUF models are large and carry their own license terms, so
  mount your own with `-v` as shown above. CI downloads a small `llama-2-7b.Q4_0.gguf` for its own
  benchmark run, but that model isn't published in this image.
- `llama-server` (OpenAI-compatible HTTP API) and `llama-bench` are installed alongside `llama-cli`
  and reachable via `--entrypoint`; the default entrypoint runs `llama-cli`.
