#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone tsne-cuda https://github.com/CannyLab/tsne-cuda.git "$(get_version tsne-cuda)"

# tsne-cuda finds its k nearest neighbours with GPU FAISS.
do_clone faiss https://github.com/facebookresearch/faiss.git "$(get_version tsne-cuda-faiss)"
