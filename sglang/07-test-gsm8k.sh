#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# End-to-end correctness: serve a real model and check its GSM8K accuracy (5-shot,
# greedy, 200 questions), with SGLang's own evaluator. A broken kernel shows up
# as garbage answers. The threshold is a floor, below the model's expected score.
source .venv/bin/activate

SGLANG_TEST_MODEL="${SGLANG_TEST_MODEL:-Qwen/Qwen2.5-1.5B-Instruct}"
SGLANG_TEST_GSM8K_THRESHOLD="${SGLANG_TEST_GSM8K_THRESHOLD:-0.55}"

python - "${SGLANG_TEST_MODEL}" "${SGLANG_TEST_GSM8K_THRESHOLD}" <<'EOF'
import sys
from types import SimpleNamespace
from urllib.parse import urlparse

from sglang.srt.utils import kill_process_tree
from sglang.test.few_shot_gsm8k import run_eval
from sglang.test.test_utils import (
    DEFAULT_TIMEOUT_FOR_SERVER_LAUNCH,
    DEFAULT_URL_FOR_TEST,
    popen_launch_server,
)

model, threshold = sys.argv[1], float(sys.argv[2])
url = urlparse(DEFAULT_URL_FOR_TEST)
server = popen_launch_server(
    model,
    DEFAULT_URL_FOR_TEST,
    timeout=DEFAULT_TIMEOUT_FOR_SERVER_LAUNCH,
    other_args=["--mem-fraction-static", "0.7"],
)
try:
    result = run_eval(
        SimpleNamespace(
            num_shots=5,
            data_path=None,
            num_questions=200,
            max_new_tokens=512,
            parallel=64,
            host=url.hostname,
            port=url.port,
            temperature=0.0,
        )
    )
finally:
    kill_process_tree(server.pid)

print(f"{model}: GSM8K accuracy {result['accuracy']:.3f}, need {threshold}")
sys.exit(int(result["accuracy"] < threshold))
EOF
