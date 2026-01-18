#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Clear the bazel cache so we always get a clean build.
rm -rf ~/.cache/bazel

# I daren't even attempt an incremental build with Tensorflow's insane build system... And Yes: out-of-tree builds
# appear to be unsupported: https://github.com/tensorflow/tensorflow/issues/250.
rm -rf "${OUT_DIR}/tensorflow/build"
cp -r --reflink=auto "${OUT_DIR}/tensorflow/tensorflow" "${OUT_DIR}/tensorflow/build"
cd "${OUT_DIR}/tensorflow/build"

# Patch
## I'm not joking. Bazel is apparently not backwards compatible.
echo "*" > .bazelversion

## Don't fortify. It doesn't work for us.
sed -E 's/"-[UD]_FORTIFY_SOURCE(=1)?",//' -i third_party/gpus/crosstool/cc_toolchain_config.bzl.tpl

## We're pretending to be nvcc, but we still don't support its insane template host/device overloading semantics.
patch -p0 < "${SCRIPT_DIR}/cwise_op_gpu.patch"

## There's a (probably upstream) compiler bug in Clang affecting the inline assembly used by this.
patch -p0 < "${SCRIPT_DIR}/aws-checksum.patch"

## I think something about numpy 1.19.0 changes the API in a const-correctness breaking way.
patch -p0 < "${SCRIPT_DIR}/python-bfloat16.patch"

# Configure.
source "${SCRIPT_DIR}"/config.sh

## Run the configure script.
./configure

# Build Tensorflow.
bazel build ${BAZEL_CONFIG} --config=v2 \
    //tensorflow:libtensorflow.so \
    //tensorflow:libtensorflow_cc.so \
    //tensorflow:install_headers \
    //tensorflow/tools/pip_package:build_pip_package \
    -j "$(nproc)"
bazel-bin/tensorflow/tools/pip_package/build_pip_package --gpu pip_out

# Install Tensorflow.
rm -rf ../install

## Install the main Python wheel.
pip3 install --ignore-installed --no-dependencies --root "${OUT_DIR}/tensorflow/install" pip_out/*.whl

## Install headers.
mv ../install/usr/lib/python*/site-packages/tensorflow/include ../install/usr/include
cp -r --reflink=auto bazel-bin/tensorflow/include/* ../install/usr/include/tensorflow/
ln -s ../../../../include ../install/usr/lib/python*/site-packages/tensorflow

## Install the libraries.
VERSION_1=$(echo pip_out/*.whl | sed -E 's;.*/tensorflow_gpu-([0-9]+)\.[0-9]+\.[0-9]+-.*;\1;')
VERSION_3=$(echo pip_out/*.whl | sed -E 's;.*/tensorflow_gpu-([0-9]+\.[0-9]+\.[0-9]+)-.*;\1;')

for LIB in tensorflow tensorflow_cc tensorflow_framework ; do
    cp --reflink=auto bazel-bin/tensorflow/lib${LIB}.so ../install/usr/lib/lib${LIB}.so.${VERSION_3}
    ln -s lib${LIB}.so.${VERSION_3} ../install/usr/lib/lib${LIB}.so.${VERSION_1}
    ln -s lib${LIB}.so.${VERSION_1} ../install/usr/lib/lib${LIB}.so
done

## Don't unnecessarily duplicate libtensorflow_framework.so.
rm ../install/usr/lib/python*/site-packages/tensorflow/libtensorflow_framework.so.${VERSION_1}
ln -s ../../../libtensorflow_framework.so.${VERSION_1} \
      ../install/usr/lib/python*/site-packages/tensorflow

## Other packages now want Tensorflow's site-packages path.
SITE_PACKAGES="$(echo "${OUT_DIR}"/tensorflow/install/usr/lib/python*/site-packages)"
export PYTHONPATH="${SITE_PACKAGES}"
echo $PYTHONPATH

# Build and install Tensorboard.
cp -r --reflink=auto "${OUT_DIR}/tensorflow/tensorboard" ./
cd tensorboard

bazel build tensorboard:tensorboard -j "$(nproc)"
bazel build //tensorboard/pip_package:build_pip_package -j "$(nproc)"

cd tensorboard/pip_package
cp -r --reflink=auto \
    ../../bazel-bin/tensorboard/pip_package/build_pip_package.runfiles/org_tensorflow_tensorboard/external ./
cp -r --reflink=auto \
    ../../bazel-bin/tensorboard/pip_package/build_pip_package.runfiles/org_tensorflow_tensorboard/tensorboard ./

python3 setup.py install --root "${OUT_DIR}/tensorflow/install" --optimize=1
cd ../../../

# Build and install Tensorflow-Estimator.
cp -r --reflink=auto "${OUT_DIR}/tensorflow/estimator" ./
cd estimator
bazel build \
    //tensorflow_estimator/tools/pip_package:build_pip_package \
    --action_env=PYTHONPATH="${PYTHONPATH}" \
    -j "$(nproc)"
bazel-bin/tensorflow_estimator/tools/pip_package/build_pip_package pip_out
pip3 install --ignore-installed --no-dependencies --root "${OUT_DIR}/tensorflow/install" pip_out/*.whl
cd ../

# Build and install Tensorflow-Model-Optimization.
cp -r --reflink=auto "${OUT_DIR}/tensorflow/model-optimization" ./
cd model-optimization
bazel build :pip_pkg -j "$(nproc)"
bazel-bin/pip_pkg ./
pip3 install --ignore-installed --no-dependencies --root "${OUT_DIR}/tensorflow/install" *.whl
cd ../

# Build and install the Tensorflow addons.
cp -r --reflink=auto "${OUT_DIR}/tensorflow/addons" ./
cd addons

for F in build_deps/toolchains/gcc7_manylinux2010-nvcc-cuda10.1/cc_toolchain_config.bzl \
         build_deps/toolchains/gpu/crosstool/CROSSTOOL.tpl \
         build_deps/toolchains/gpu/crosstool/cc_toolchain_config.bzl.tpl ; do
    sed -E 's/-D_FORTIFY_SOURCE=1/-D_FORTIFY_SOURCE=0/' -i "${F}"
done

python3 ./configure.py --no-deps
bazel build build_pip_pkg -j "$(nproc)"
bazel-bin/build_pip_pkg pip_out
pip3 install --ignore-installed --no-dependencies --root "${OUT_DIR}/tensorflow/install" pip_out/*.whl
cd ../

# Build and install Tensorflow-Metadata.
cp -r --reflink=auto "${OUT_DIR}/tensorflow/metadata" ./
cd metadata
bazel build //tensorflow_metadata:build_pip_package -j "$(nproc)"
python3 setup.py install --root "${OUT_DIR}/tensorflow/install" --optimize=1 --skip-build
mkdir -p ${SITE_PACKAGES}/tensorflow_metadata/proto/
cp -r --reflink=auto bazel-bin/tensorflow_metadata/proto/v0 ${SITE_PACKAGES}/tensorflow_metadata/proto
cd ../

# Build and install Tensorflow-Datasets.
cp -r --reflink=auto "${OUT_DIR}/tensorflow/datasets" ./
cd datasets
python3 setup.py install --root "${OUT_DIR}/tensorflow/install" --optimize=1
cd ../
