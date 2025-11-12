#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/whispercpp/whispercpp"

set -o pipefail

# Do the moral equivalent of make base.en -j10 | tee output.txt

# Download the base model
bash ./models/download-ggml-model.sh base.en

# Download the samples too
make samples

# Like the `make base.en target`, except run the sample on the GPU build
# That is ./main is cpu-only, ./build/bin/main is the gpu build

for f in samples/*.wav; do
    echo "----------------------------------------------"
    echo ""
    ./build/bin/main -m models/ggml-base.en.bin -f "$f" &> "$f.out"
    echo ""
done


cat samples/jfk.wav.out | grep "And so my fellow Americans, ask not what your country can do for you, ask what you can do for your country."
