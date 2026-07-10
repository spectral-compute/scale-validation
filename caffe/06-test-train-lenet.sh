#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

# data/mnist/get_mnist.sh fetches from yann.lecun.com, which now 404s on
# every file -- pull from the ossci-datasets mirror instead (the same one
# PyTorch/torchvision switched to after hitting the same dead host).
mkdir -p caffe/data/mnist
(
    cd caffe/data/mnist
    for f in train-images-idx3-ubyte train-labels-idx1-ubyte t10k-images-idx3-ubyte t10k-labels-idx1-ubyte; do
        wget -q "https://ossci-datasets.s3.amazonaws.com/mnist/${f}.gz"
        gunzip -f "${f}.gz"
    done
)

# Idempotent -- a no-op if 02-build.sh's `make install` already built this as
# a side effect of building the `all` target.
make -O -C build -j"$(nproc)" convert_mnist_data

# create_mnist.sh expects a `build/` directory inside the clone itself,
# pointing at the real out-of-source build directory.
(
    cd caffe
    ln -sfn ../build build
    bash examples/mnist/create_mnist.sh
    sed -e 's/^max_iter:.*/max_iter: 100/' -e 's/^test_interval:.*/test_interval: 100000/' \
        examples/mnist/lenet_solver.prototxt > examples/mnist/lenet_solver_short.prototxt
)

# Exercises the backward-pass/gradient kernels, never touched by the
# forward-pass-only checks in 04-test-cli.sh / 05-test-model-zoo.sh.
check_train_lenet_short() {
    (cd caffe && ../../install/bin/caffe train -solver=examples/mnist/lenet_solver_short.prototxt -gpu 0 &> ../train.log || true)
    tail -40 train.log
    grep -qi 'Optimization Done' train.log
}

check "LeNet training completes (100 iters, backward-pass kernels)" check_train_lenet_short

check_exit
