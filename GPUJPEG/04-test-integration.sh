#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh

source "$SCALE_VALIDATION/util/checks.sh"

# 02-build.sh never runs `make install`, so gpujpegtool isn't guaranteed to
# find libgpujpeg.so via rpath alone -- cheap insurance.
LD_LIBRARY_PATH="$(pwd)/build:${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH

# psnr_ppm <ref> <dec> [<threshold_db=30>]
# Computes PSNR between two PPM or PGM files (P6 = 3-channel, P5 = 1-channel).
# Prints "PSNR = X.XX dB [OK|LOW]" and returns nonzero if below threshold, or
# if either file can't be read or their dimensions mismatch.
psnr_ppm() {
    local ref="$1" dec="$2" thresh="${3:-30}"
    python3 - "$ref" "$dec" "$thresh" <<'PYEOF'
import sys, math

def read_ppm(path):
    with open(path, 'rb') as f:
        magic = f.readline().strip()
        while True:
            line = f.readline().strip()
            if not line.startswith(b'#'):
                break
        w, h = map(int, line.split())
        maxv  = int(f.readline().strip())
        data  = f.read()
    channels = 3 if magic == b'P6' else 1
    return w, h, maxv, data, channels

ref_path, dec_path, thresh = sys.argv[1], sys.argv[2], float(sys.argv[3])
try:
    w1, h1, mv1, d1, ch1 = read_ppm(ref_path)
    w2, h2, mv2, d2, ch2 = read_ppm(dec_path)
except Exception as e:
    print(f'  cannot read PPM/PGM -- {e}')
    sys.exit(1)
if w1 != w2 or h1 != h2:
    print(f'  dimension mismatch {w1}x{h1} vs {w2}x{h2}')
    sys.exit(1)
ch  = min(ch1, ch2)
n   = w1 * h1 * ch
mse = sum((a - b) ** 2 for a, b in zip(d1[:n], d2[:n])) / n
if mse == 0:
    print('  PSNR = inf dB  [lossless]')
else:
    psnr = 10 * math.log10((mv1 ** 2) / mse)
    ok   = psnr >= thresh
    tag  = 'OK' if ok else f'LOW -- below {thresh:.0f} dB'
    print(f'  PSNR = {psnr:.2f} dB  [{tag}]')
    if not ok:
        sys.exit(1)
PYEOF
}

convert -size 256x256 -depth 8 gradient:blue-red test_input.ppm

check_encode() {
    ./build/gpujpegtool --encode test_input.ppm test_output.jpg &&
        [ -s test_output.jpg ]
}

check_decode() {
    ./build/gpujpegtool --decode test_output.jpg test_decoded.ppm &&
        [ -s test_decoded.ppm ]
}

check_roundtrip_psnr() {
    psnr_ppm test_input.ppm test_decoded.ppm 30
}

check_interop_standard_decoder() {
    ./build/gpujpegtool --encode test_input.ppm interop_gpu.jpg &&
        convert interop_gpu.jpg interop_stddec.ppm &&
        psnr_ppm test_input.ppm interop_stddec.ppm 30
}

check_interop_gpu_decodes_standard_jpeg() {
    convert -quality 75 test_input.ppm interop_std.jpg &&
        ./build/gpujpegtool --decode interop_std.jpg interop_gpudec.ppm &&
        psnr_ppm test_input.ppm interop_gpudec.ppm 30
}

check_quality_size_ordering() {
    ./build/gpujpegtool --encode --quality 10 test_input.ppm q10.jpg &&
        ./build/gpujpegtool --encode --quality 90 test_input.ppm q90.jpg ||
        return 1
    local q10 q90
    q10="$(stat -c%s q10.jpg)"
    q90="$(stat -c%s q90.jpg)"
    log "q10.jpg: ${q10} bytes   q90.jpg: ${q90} bytes"
    ((q90 > q10))
}

# JPEG at quality 100 is still lossy, but PSNR should be very high on a clean
# encoder/decoder pair.
check_quality_100_near_lossless() {
    ./build/gpujpegtool --encode --quality 100 test_input.ppm q100.jpg &&
        ./build/gpujpegtool --decode q100.jpg q100_dec.ppm &&
        psnr_ppm test_input.ppm q100_dec.ppm 40
}

# Shared by every colorspace/subsampling variant below: encode with the given
# extra flags, decode without them (gpujpegtool auto-detects from the JPEG
# headers), then check round-trip fidelity.
_roundtrip_variant() {
    local name="$1"
    shift
    ./build/gpujpegtool --encode "$@" test_input.ppm "${name}.jpg" &&
        ./build/gpujpegtool --decode "${name}.jpg" "${name}_dec.ppm" &&
        psnr_ppm test_input.ppm "${name}_dec.ppm" 30
}

check_colorspace_rgb() { _roundtrip_variant cs_rgb --colorspace rgb; }

# --colorspace gives the colorspace of the input data, so a YCbCr round trip needs YCbCr input:
# raw 4:4:4 full-range YCbCr gradients (NVIDIA: 52.5 dB).
check_colorspace_ycbcr_jpeg() {
    python3 - <<'PYEOF' &&
out = bytearray()
for y in range(256):
    for x in range(256):
        out += bytes((x, y, (x + y) // 2))
open('ycc.yuv', 'wb').write(out)
PYEOF
        ./build/gpujpegtool --encode -s 256x256 -c ycbcr-jpeg -f 444-u8-p012 ycc.yuv ycc.jpg &&
        ./build/gpujpegtool --decode -c ycbcr-jpeg -f 444-u8-p012 ycc.jpg ycc_dec.yuv &&
        python3 - <<'PYEOF'
import math, sys
a = open('ycc.yuv', 'rb').read()
b = open('ycc_dec.yuv', 'rb').read()
if len(a) != len(b):
    sys.exit(f'  size mismatch {len(a)} vs {len(b)}')
mse = sum((x - y) ** 2 for x, y in zip(a, b)) / len(a)
psnr = 10 * math.log10(255 ** 2 / mse) if mse else math.inf
print(f'  PSNR = {psnr:.2f} dB')
sys.exit(psnr < 40)
PYEOF
}
check_subsampling_444() { _roundtrip_variant sub_444 --subsampled=4:4:4; }
check_subsampling_420() { _roundtrip_variant sub_420; }

# Decoding a 1-component JPEG requires requesting single-channel output
# (--pixel-format u8) on both encode and decode.
check_format_grayscale() {
    convert -colorspace gray -depth 8 test_input.ppm gray.pgm &&
        ./build/gpujpegtool --encode --pixel-format u8 gray.pgm gray.jpg &&
        ./build/gpujpegtool --decode --pixel-format u8 gray.jpg gray_dec.pgm &&
        psnr_ppm gray.pgm gray_dec.pgm 30
}

check "encode produces a JPEG" check_encode
check "decode produces a PPM" check_decode
check "decode round-trip PSNR >= 30 dB" check_roundtrip_psnr
check "GPU-encoded JPEG opens in a standard decoder" check_interop_standard_decoder
check "GPU decodes a standard-encoder JPEG" check_interop_gpu_decodes_standard_jpeg
check "quality 90 output larger than quality 10" check_quality_size_ordering
check "quality 100 round-trip PSNR >= 40 dB" check_quality_100_near_lossless
check "rgb round-trip" check_colorspace_rgb
check "ycbcr-jpeg round-trip" check_colorspace_ycbcr_jpeg
check "4:4:4 subsampling round-trip" check_subsampling_444
check "4:2:0 subsampling round-trip" check_subsampling_420
check "grayscale (u8) round-trip" check_format_grayscale

check_exit
