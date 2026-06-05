# Hashcat

Hashcat is the world's fastest and most advanced password recovery utility, supporting over 300
distinct hash types — MD5, SHA-1, SHA-2, SHA-3, bcrypt, scrypt, WPA-PBKDF2, and many more. It
uses GPU acceleration to maximise cracking throughput. With SCALE, Hashcat's CUDA backend runs on
AMD GPUs with no modifications.

> **Note:** Hashcat is a security research and authorised penetration-testing tool. Only use it
> against hashes you own or have explicit written permission to test.

## Quick Start with Docker

Build Hashcat with SCALE in a single `docker build`. Pass `--build-arg GPU_ARCH=<your-gfx>` to
target a different AMD GPU (e.g. `gfx942`, `gfx1201`).

[Dockerfile](./Dockerfile)

## Try it locally

```bash
# From the scale-validation repository root:
docker build --build-arg GPU_ARCH=gfx1100 -t hashcat:scale -f hashcat/Dockerfile .

# List available options (no GPU required):
docker run --rm hashcat:scale --help

# Benchmark SHA-256 throughput on your GPU:
docker run --rm --device /dev/dri --device /dev/kfd \
  hashcat:scale -m 1400 -b

# Smoke test — crack a known SHA-256 hash (should recover "test" in seconds):
HASH=$(echo -n test | sha256sum | cut -d' ' -f1)
docker run --rm --device /dev/dri --device /dev/kfd \
  hashcat:scale --potfile-disable -O -m 1400 -a 3 "$HASH"
# Expected: <hash>:test   Status: Cracked

# Crack hashes from a wordlist (mount your files at /work):
# docker run --rm --device /dev/dri --device /dev/kfd \
#   -v "$PWD:/work" \
#   hashcat:scale -m 1400 -a 0 /work/hashes.txt /work/wordlist.txt
```

## Build from source

[00-clone.sh](./00-clone.sh)

[01-build.sh](./01-build.sh)

See the [SCALE installation guide](https://docs.scale-lang.com/stable/manual/tutorials/how-to-install/)
for instructions on getting SCALE on your system.

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
