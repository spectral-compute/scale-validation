# Caffe

Caffe is a deep learning framework from Berkeley AI Research (BAIR) built for speed and
expressiveness. It supports CNNs, RCNNs, LSTMs, and fully-connected networks, with GPU-accelerated
training and inference via CUDA. With SCALE, Caffe's full CUDA layer library runs on AMD GPUs.

## Quick Start with Docker

Build Caffe with SCALE in a single `docker build`. Pass `--build-arg GPU_ARCH=<your-gfx>` to
target a different AMD GPU (e.g. `gfx942`, `gfx1201`).

[Dockerfile](./Dockerfile)

## Try it locally

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t caffe:scale -f caffe/Dockerfile .

# List available Caffe commands (no GPU required)
docker run --rm caffe:scale --help

# Verify GPU detection (requires an AMD GPU)
docker run --rm --device /dev/dri --device /dev/kfd caffe:scale device_query

# Train a model (mount your solver and data files at /work):
# docker run --rm --device /dev/dri --device /dev/kfd \
#   -v "$PWD:/work" caffe:scale train -solver /work/solver.prototxt
```

## Build from source

[00-clone.sh](./00-clone.sh)

[01-patch.sh](./01-patch.sh)

[02-build.sh](./02-build.sh)

See the [SCALE installation guide](https://docs.scale-lang.com/stable/manual/tutorials/how-to-install/)
for instructions on getting SCALE on your system.

## Notes

- All standard CUDA layers are validated (convolution, pooling, batch norm, softmax, ReLU, etc.).
- cuDNN integration is disabled in this configuration.
- The `sed` patch updates a protobuf API call (`SetTotalBytesLimit`) that changed signature in
  newer versions of protobuf; it has no effect on model accuracy or GPU behaviour.
- The pre-trained Caffe Model Zoo (`.caffemodel` files) is fully compatible with this build.
