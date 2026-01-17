#!/bin/bash
set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

cd ${OUT_DIR}/gpu_jpeg2k

if ! [ -f BSDS300-images.tgz ]; then
    wget -q https://www2.eecs.berkeley.edu/Research/Projects/CS/vision/bsds/BSDS300-images.tgz
    tar -xzf BSDS300-images.tgz
fi

# Correct answers live here.
if ! [ -d gpu_jpeg_cuda_imgs ]; then
    git clone https://gitlab.com/manos5/gpu_jpeg_cuda_imgs.git
    cd gpu_jpeg_cuda_imgs
    tar xf native_outputs.tar
    cd -
fi

input_dir="BSDS300/images/train/"
output_dir="BSDS300_Out"
native_dir="gpu_jpeg_cuda_imgs/BSDS300_Nat"

if [ ! -d "$native_dir" ]; then
    echo "Error: Directory $native_dir does not exist."
    exit 1
fi

mkdir -p "$output_dir"

function check_difference() {
    LEFT="$1"
    RIGHT="$2"

    CMP="$(compare -metric mse "$LEFT" "$RIGHT" /dev/null 2>&1 | cut -f 1 -d ' ')"

    if [ "$(echo "print(${CMP} < 0.06)" | python3)" == "True" ]; then
        return 0
    else
        return 1
    fi
}

EXIT_CODE=0
for file in "$input_dir"/*.jpg; do
    filename=$(basename "$file" .jpg)
    output_file=$output_dir/$filename.j2k
    native_file="$native_dir/$filename.j2k"

    # Run the encoding command
    ./build/encoder -i "$file" -o "$output_dir/$filename.j2k"
    echo "Encoded $file to $output_file"

    if check_difference "$output_file" "$native_file"; then
        echo -e "\x1b[32;1mPassed\x1b[m with \x1b[1m${CMP}\x1b[m\n"
    else
        EXIT_CODE=1
        echo -e "\x1b[31;1mFailed\x1b[m with \x1b[1m${CMP}\x1b[m for \x1b[33;1m${filename}.j2k\x1b[m vs \x1b[33;1m${native_file}\x1b[m\n"
    fi
done

exit $EXIT_CODE
