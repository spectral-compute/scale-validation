#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

if ! [ -f HIGGS_prepared.tar.xz ]; then
    wget -nv -nc https://data.spectralcompute.co.uk/lightgbm/HIGGS_prepared.tar.xz
    tar -xf HIGGS_prepared.tar.xz
fi

cat >lightgbm_gpu.conf <<EOF
max_bin = 63
num_leaves = 255
num_iterations = 50
learning_rate = 0.1
tree_learner = serial
task = train
is_training_metric = false
min_data_in_leaf = 1
min_sum_hessian_in_leaf = 100
ndcg_eval_at = 1,3,5,10
device = cuda
gpu_platform_id = 0
gpu_device_id = 0
EOF
echo "num_threads=$(nproc)" >>lightgbm_gpu.conf

./install/bin/lightgbm config=lightgbm_gpu.conf data=higgs.train valid=higgs.test objective=binary metric=rmse |
    tee train.log

# NVIDIA (CUDA 12.9, sm_120) reaches this validation RMSE after 50 iterations. The CUDA learner sums
# histograms with float atomics, so allow a little slack for summation order.
expected=0.41561
actual=$(grep -oP 'Iteration:50, valid_1 rmse : \K[0-9.]+' train.log)
log "Final validation RMSE: ${actual} (NVIDIA: ${expected})"
python3 -c "import sys; sys.exit(abs(${actual} - ${expected}) > 1e-3)"
