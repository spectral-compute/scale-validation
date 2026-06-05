# Whisper.cpp

whisper.cpp is a high-performance C/C++ inference engine for OpenAI's Whisper automatic speech
recognition model. It supports all model sizes (tiny → large) and uses CUDA for GPU-accelerated
inference. With SCALE, whisper.cpp runs on AMD GPUs at full speed using its standard CUDA build
path — no HIP port or code changes required.

## Try it locally

Pull the prebuilt SCALE image and transcribe the bundled sample audio on your AMD GPU — no build
step required.

```bash
docker pull docker.io/spectralcompute/whispercpp:latest

# Download a model first (run once; ~140 MB for base.en):
mkdir -p models
wget -q -O models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

# Transcribe the bundled JFK sample (requires an AMD GPU):
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD/models:/models" \
  docker.io/spectralcompute/whispercpp:latest \
  -m /models/ggml-base.en.bin \
  -f /build/whispercpp/whispercpp/samples/jfk.wav
# Expected: "And so my fellow Americans, ask not what your country can do for you..."
```

Also available on Quay as `quay.io/spectral-compute/whispercpp:latest`. If pull doesn't work for
your GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**Transcribe your own audio** (mount it alongside the model):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD/models:/models" -v "$PWD:/audio" \
  docker.io/spectralcompute/whispercpp:latest -m /models/ggml-base.en.bin -f /audio/recording.wav
```

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs — no drift between what you
build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t whispercpp:scale -f whispercpp/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `whispercpp:scale` for the pulled tag in any example above.

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/whispercpp/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

[Dockerfile](./Dockerfile)

</details>

## Notes

- Built on top of [ggml](https://github.com/ggml-org/ggml), a tensor library for ML.
- All model sizes (tiny, base, small, medium, large) are supported.
- `GGML_CUDA_NO_PEER_COPY=ON` disables GPU-to-GPU peer copies, which are not needed for
  single-GPU inference and avoids a compatibility issue on some AMD configurations.
- `whisper-cli` is the GPU-accelerated CLI entrypoint; `main` in the same bin directory is a
  deprecated alias for the same binary.
