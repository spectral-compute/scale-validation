#!/bin/bash

set -e
set -o pipefail

cd "whispercpp"

# Do the moral equivalent of make base.en -j10 | tee output.txt

# Download the base model
bash ./models/download-ggml-model.sh base.en

# Download the samples too
mkdir -p samples
wget -nv -O samples/a13.wav https://data.spectralcompute.co.uk/whispercpp/a13.wav
wget -nv -O samples/diffusion2023-07-03.wav https://data.spectralcompute.co.uk/whispercpp/diffusion2023-07-03.wav
wget -nv -O samples/gb0.wav https://data.spectralcompute.co.uk/whispercpp/gb0.wav
wget -nv -O samples/gb1.wav https://data.spectralcompute.co.uk/whispercpp/gb1.wav
wget -nv -O samples/hp0.wav https://data.spectralcompute.co.uk/whispercpp/hp0.wav
wget -nv -O samples/mm1.wav https://data.spectralcompute.co.uk/whispercpp/mm0.wav

# Like the `make base.en target`, except run the sample on the GPU build
# That is ./main is cpu-only, ./build/bin/main is the gpu build

for f in samples/*.wav; do
    echo "Processing $f..."
    ../build/bin/main -m ./models/ggml-base.en.bin -f "$f" &> "$f.out"
done


cat samples/jfk.wav.out | grep "And so my fellow Americans, ask not what your country can do for you, ask what you can do for your country."
