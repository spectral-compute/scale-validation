# Whisper.cpp

whisper.cpp is a high-performance C/C++ inference engine for OpenAI's Whisper automatic speech
recognition model. It supports all model sizes (tiny → large) and uses CUDA for GPU-accelerated
inference. With SCALE, whisper.cpp runs on AMD GPUs at full speed using its standard CUDA build
path — no HIP port or code changes required.

## Quick Start with Docker

Build whisper.cpp with SCALE in a single `docker build`. Pass `--build-arg GPU_ARCH=<your-gfx>`
to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).

[Dockerfile](./Dockerfile)

## Try it locally

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t whispercpp:scale -f whispercpp/Dockerfile .

# Download a model first (run once; ~140 MB for base.en):
mkdir -p models
wget -q -O models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

# Transcribe the bundled JFK sample (requires an AMD GPU):
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD/models:/models" \
  whispercpp:scale \
  -m /models/ggml-base.en.bin \
  -f /build/whispercpp/whispercpp/samples/jfk.wav
# Expected: "And so my fellow Americans, ask not what your country can do for you..."

# Transcribe your own audio (mount it alongside the model):
# docker run --rm --device /dev/dri --device /dev/kfd \
#   -v "$PWD/models:/models" -v "$PWD:/audio" \
#   whispercpp:scale -m /models/ggml-base.en.bin -f /audio/recording.wav
```

## Build from source

[00-clone.sh](./00-clone.sh)

[01-build.sh](./01-build.sh)

See the [SCALE installation guide](https://docs.scale-lang.com/stable/manual/tutorials/how-to-install/)
for instructions on getting SCALE on your system.

## Notes

- Built on top of [ggml](https://github.com/ggml-org/ggml), a tensor library for ML.
- All model sizes (tiny, base, small, medium, large) are supported.
- `GGML_CUDA_NO_PEER_COPY=ON` disables GPU-to-GPU peer copies, which are not needed for
  single-GPU inference and avoids a compatibility issue on some AMD configurations.
- `whisper-cli` is the GPU-accelerated CLI entrypoint; `main` in the same bin directory is a
  deprecated alias for the same binary.
