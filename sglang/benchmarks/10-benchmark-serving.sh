#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh
source "${SCRIPT_DIR}/util/bench-env.sh"

# Online serving through the HTTP server, as users run SGLang: time to first
# token, inter-token latency and throughput, at a few request rates (Poisson
# arrivals; inf sends everything at once).
out="$(results_file serving)"
python - "${out}" "${bench_args[@]}" <<'EOF'
import subprocess
import sys

from sglang.srt.utils import kill_process_tree
from sglang.test.test_utils import (
    DEFAULT_TIMEOUT_FOR_SERVER_LAUNCH,
    DEFAULT_URL_FOR_TEST,
    popen_launch_server,
)

out, server_args = sys.argv[1], sys.argv[2:]
model = server_args[server_args.index("--model-path") + 1]
server_args = [a for a in server_args if a not in ("--model-path", model)]
server = popen_launch_server(
    model,
    DEFAULT_URL_FOR_TEST,
    timeout=DEFAULT_TIMEOUT_FOR_SERVER_LAUNCH,
    other_args=server_args,
)
try:
    for rate in ("4", "16", "inf"):
        subprocess.run(
            [
                sys.executable, "-m", "sglang.benchmark.serving",
                "--backend", "sglang",
                "--base-url", DEFAULT_URL_FOR_TEST,
                "--model", model,
                "--dataset-name", "random-ids",
                "--num-prompts", "300",
                "--random-input-len", "512",
                "--random-output-len", "128",
                "--request-rate", rate,
                "--seed", "42",
                "--output-file", out,
            ],
            check=True,
        )
finally:
    kill_process_tree(server.pid)
EOF
check_results "${out}"
