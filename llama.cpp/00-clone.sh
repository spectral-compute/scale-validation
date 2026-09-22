#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone llama.cpp https://github.com/ggerganov/llama.cpp "$(get_version llama.cpp)"

mkdir -p models
(cd models && wget -nc -nv https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/llama-2-7b.Q4_0.gguf)
