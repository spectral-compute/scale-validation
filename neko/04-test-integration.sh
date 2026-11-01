#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
# shellcheck source=util/env.sh
. "${SCRIPT_DIR}/util/env.sh"

python3 -m venv venv
venv/bin/pip install pytest json5 jsonschema numpy

NEKO_EXEC="$(realpath install/bin/neko)"
MAKENEKO_EXEC="$(realpath install/bin/makeneko)"
export NEKO_EXEC MAKENEKO_EXEC
cd neko/tests/integration
# One rank: one GPU.
../../../venv/bin/pytest --backend=cuda --max_nprocs=1 \
    --launcher-script="$(realpath ./default_cpu_launcher.sh)"
