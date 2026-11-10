#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

if ! [ -f BSDS300-images.tgz ]; then
    # Some images, and the result of running them through this on nvidia.
    wget -q https://data.spectralcompute.co.uk/gpu_jpeg2k/BSDS300-images.tgz
    wget -q https://data.spectralcompute.co.uk/gpu_jpeg2k/BSDS300-images-ref.tgz
    tar -xzf BSDS300-images.tgz
    tar -xzf BSDS300-images-ref.tgz
fi

input_dir="BSDS300/images/train/"
output_dir="BSDS300_Out"
native_dir="BSDS300_Nat"

if [ ! -d "$native_dir" ]; then
    log "Error: Directory $native_dir does not exist."
    exit 1
fi

mkdir -p "$output_dir"

function mse() {
    compare -metric mse "$1" "$2" /dev/null 2>&1 | cut -f 1 -d ' '
}

# Passes if the output is close to NVIDIA's, or at least as close to the input as NVIDIA's is: the
# encoder works in floating point, so rounding differences can move a few images past the first test.
function check_difference() {
    OURS="$1"
    NATIVE="$2"
    INPUT="$3"

    CMP="$(mse "$OURS" "$NATIVE")"
    if [ "$(echo "print(${CMP} < 0.06)" | python3)" == "True" ]; then
        return 0
    fi

    OURS_ERR="$(mse "$INPUT" "$OURS")"
    NATIVE_ERR="$(mse "$INPUT" "$NATIVE")"
    CMP="${CMP} (error ${OURS_ERR}, NVIDIA's ${NATIVE_ERR})"
    [ "$(echo "print(${OURS_ERR} <= ${NATIVE_ERR} * 1.001)" | python3)" == "True" ]
}

EXIT_CODE=0
for file in "$input_dir"/*.jpg; do
    filename=$(basename "$file" .jpg)
    output_file=$output_dir/$filename.j2k
    native_file="$native_dir/$filename.j2k"

    # Run the encoding command
    ./build/encoder -i "$file" -o "$output_dir/$filename.j2k"
    log "Encoded $file to $output_file"

    if check_difference "$output_file" "$native_file" "$file"; then
        log "Passed with ${CMP}"
    else
        EXIT_CODE=1
        echo -e "Failed with ${CMP} for ${filename}.j2k vs ${native_file}"
    fi
done

exit $EXIT_CODE
