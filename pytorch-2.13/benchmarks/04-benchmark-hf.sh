#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# PyTorch's HuggingFace suite as its inductor dashboard runs it: inference, bf16, compiled against eager. HF_ARGS adds
# harness options, e.g. HF_ARGS="--only BertForMaskedLM".
results="$(realpath "${RESULTS_DIR:-.}")"
stamp="$(date -u +%Y%m%d%H%M%SZ)"
name="pytorch-hf.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH:-unknown}.r${BENCHMARK_REPEAT:-1}.${stamp}.csv"
out="${results}/${name}"
read -ra extra <<< "${HF_ARGS:-}"

# A fresh inductor cache for each benchmark.py run, so a rebuilt torch never reuses code compiled for the last one.
cache="$(realpath -m inductor-cache)"
if [[ "${BENCHMARK_REPEAT:-1}" == 1 ]]; then
    rm -rf "${cache}"
fi
export TORCHINDUCTOR_CACHE_DIR="${cache}"

cd pytorch
source .venv/bin/activate
python benchmarks/dynamo/huggingface.py --performance --inference --bfloat16 --backend inductor --device cuda \
    --output "${out}" "${extra[@]}"
