# Caffe

Caffe is a deep learning framework from Berkeley AI Research (BAIR) built for speed and
expressiveness. It supports CNNs, RCNNs, LSTMs, and fully-connected networks, with GPU-accelerated
training and inference via CUDA. With SCALE, Caffe's full CUDA layer library runs on AMD GPUs.

## Try it locally

Pull the prebuilt SCALE image and verify it detects your AMD GPU — no build step required.

```bash
docker pull docker.io/spectralcompute/caffe:latest

# Verify GPU detection (requires an AMD GPU):
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/caffe:latest device_query
```

Also available on Quay as `quay.io/spectral-compute/caffe:latest`. If pull doesn't work for your
GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**List available Caffe commands** (no GPU required):

```bash
docker run --rm docker.io/spectralcompute/caffe:latest --help
```

**Train a model** (mount your solver and data files at `/work`):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" docker.io/spectralcompute/caffe:latest train -solver /work/solver.prototxt
```

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs — no drift between what you
build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t caffe:scale -f caffe/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `caffe:scale` for the pulled tag in any example above.

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/caffe/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

[Dockerfile](./Dockerfile)

</details>

## Notes

- All standard CUDA layers are validated (convolution, pooling, batch norm, softmax, ReLU, etc.).
- cuDNN integration is disabled in this configuration.
- The `sed` patch updates a protobuf API call (`SetTotalBytesLimit`) that changed signature in
  newer versions of protobuf; it has no effect on model accuracy or GPU behaviour.
- The pre-trained Caffe Model Zoo (`.caffemodel` files) is fully compatible with this build.
