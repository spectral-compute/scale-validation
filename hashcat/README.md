# Hashcat

Hashcat is the world's fastest and most advanced password recovery utility, supporting over 300
distinct hash types — MD5, SHA-1, SHA-2, SHA-3, bcrypt, scrypt, WPA-PBKDF2, and many more. It
uses GPU acceleration to maximise cracking throughput. With SCALE, Hashcat's CUDA backend runs on
AMD GPUs with no modifications.

> **Note:** Hashcat is a security research and authorised penetration-testing tool. Only use it
> against hashes you own or have explicit written permission to test.

## Try it locally

Pull the prebuilt SCALE image and crack a known hash on your AMD GPU as a smoke test — no build
step required.

```bash
docker pull docker.io/spectralcompute/hashcat:latest

# Crack a known SHA-256 hash (should recover "test" in seconds):
HASH=$(echo -n test | sha256sum | cut -d' ' -f1)
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/hashcat:latest --potfile-disable -O -m 1400 -a 3 "$HASH"
# Expected: <hash>:test   Status: Cracked
```

Also available on Quay as `quay.io/spectral-compute/hashcat:latest`. If pull doesn't work for
your GPU, or you'd rather build from source, see "Advanced" below.

<details>
<summary>Advanced usage, building it yourself, and build from source</summary>

**List available options** (no GPU required):

```bash
docker run --rm docker.io/spectralcompute/hashcat:latest --help
```

**Benchmark SHA-256 throughput** on your GPU:

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  docker.io/spectralcompute/hashcat:latest -m 1400 -b
```

**Crack hashes from a wordlist** (mount your files at `/work`):

```bash
docker run --rm --device /dev/dri --device /dev/kfd \
  -v "$PWD:/work" \
  docker.io/spectralcompute/hashcat:latest -m 1400 -a 0 /work/hashes.txt /work/wordlist.txt
```

### Build it yourself

The Dockerfile calls the exact same numbered build scripts CI runs — no drift between what you
build and what CI validates.

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t hashcat:scale -f hashcat/Dockerfile .
```

Pass `--build-arg GPU_ARCH=<your-gfx>` to target a different AMD GPU (e.g. `gfx942`, `gfx1201`).
Substitute `hashcat:scale` for the pulled tag in any example above.

This [Dockerfile](https://github.com/spectral-compute/scale-validation/blob/feature/app-hub/hashcat/Dockerfile)
lives in this directory of the `scale-validation` repository. It's meant to be used in-tree, not
standalone: it runs the numbered build scripts alongside it and depends on `util/` and
`versions.txt` from the repository root, so build it from there (as shown above).

[Dockerfile](./Dockerfile)

</details>

## Notes

- Hashcat discovers its support files (modules, kernels, OpenCL sources) relative to its binary
  path — the container keeps them together automatically, so no extra setup is needed.
- The SCALE image provides the CUDA backend only; HIP and OpenCL backends are not present.
  `--backend-ignore-hip --backend-ignore-opencl` is used in CI to avoid backend-detection noise;
  you can add these flags if Hashcat reports warnings about unavailable backends.
- The `-O` flag enables optimised kernels (max-length constraint applies); omit it for passwords
  longer than 31 characters.
- `--potfile-disable` prevents writing a potfile during quick tests. Remove it to persist recovered
  hashes across runs; use `--potfile-path /work/my.potfile` with a mounted volume for persistence.
- Hashcat validates against commit `6716447` (see `versions.txt`).
