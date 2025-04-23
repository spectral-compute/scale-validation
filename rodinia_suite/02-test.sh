#!/bin/bash
# Function to compare two files
compare_files() {
    local file1="$1"
    local file2="$2"
    local logfile="diff_log.txt"
    # Check if both files exist
    if [[ ! -f "$file1" ]]; then
        echo "Error: File '$file1' does not exist."
        return 2
    fi

    if [[ ! -f "$file2" ]]; then
        echo "Error: File '$file2' does not exist."
        return 2
    fi

    #echo "compare files!!"
    # Compare the two files using diff
    local diff_output
    #echo ${file1}
    #echo ${file2}
    diff_output=$(diff "$file1" "$file2")
    #echo "compare files!!"
    # Check if diff_output is empty
    if [ -z "$diff_output" ]; then
	echo "[   PASS            ]"
        return 0
    else
	echo "[   FAIL            ]"
        echo "$diff_output" > "$logfile"
        echo "Differences logged to $logfile"
        return 1
    fi
}

# Initialize counters
passed_benchmarks=0
failed_benchmarks=0
#set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd ${OUT_DIR}/rodinia_suite/rodinia_suite/cuda

export SCALE_EXCEPTIONS=2
benchmarks=("backprop" "bfs" "b+tree" "cfd" "dwt2d" "gaussian" "heartwall" "hotspot" "hotspot3D" "huffman" "lavaMD" "nn" "nw" "particlefilter" "pathfinder")
total_benchmarks=${#benchmarks[@]}
echo "[===================]"
for str in ${benchmarks[@]}
do
    echo "[ RUN               ] $str"
    if [ "$str" = "particlefilter" ]; then
        echo "[   NOT SUPPORTED   ] $str"
        continue
    fi
    cd ${str}
    path=$(pwd)
    ./run.sh ${path} ${str}.csv
    if [ "$str" = "cfd" ]; then
	    FILE1="result_density_energy.txt"
	    FILE2="nat_result_density_energy.txt"
    elif [ "$str" = "dwt2d" ]; then
	    FILE1="rgb.bmp.dwt.g"
	    FILE2="rgb.bmp.dwt_nat.g"
    else 
	    FILE1="result.txt"
	    FILE2="nat_result.txt"
    fi
    # Compare files and update counters
    if compare_files "$FILE1" "$FILE2"; then
        ((passed_benchmarks++))
    else
        ((failed_benchmarks++))
    fi
    value=$(grep "Computation" "average.csv" |  awk -F',' '{printf "%.2f", $2}')
    echo "[   AVG GPU time    ] $value ms"
    cd - &>/dev/null
done
# Print the summary
echo "[===================] $total_benchmarks apps ran."
echo "[       PASSED      ] $passed_benchmarks apps."
echo "[       FAILED      ] $failed_benchmarks apps."

unset SCALE_NONFATAL_EXCEPTIONS

