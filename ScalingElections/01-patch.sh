#!/bin/bash
set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

SRCDIR="${OUT_DIR}/scaling-elections/ScalingElections"
cd "${SRCDIR}"

python - <<'PY'
import re
from pathlib import Path

p = Path("scaling_elections.cu")
t0 = p.read_text()
t = t0
changed = False

# Disable ONLY the barrier alias block:
#   #if !defined(SCALING_ELECTIONS_WITH_HIP)
#   namespace cde = cuda::device::experimental;
#   using barrier_t = cuda::barrier<cuda::thread_scope_block>;
#   #endif
pat_barrier = re.compile(
    r'(?ms)^#if\s*!defined\s*\(\s*SCALING_ELECTIONS_WITH_HIP\s*\)\s*'
    r'\n\s*namespace\s+cde\s*=\s*cuda::device::experimental\s*;\s*'
    r'\n\s*using\s+barrier_t\s*=\s*cuda::barrier\s*<\s*cuda::thread_scope_block\s*>\s*;\s*'
    r'\n\s*#endif\s*'
)

# If already disabled, skip.
already_disabled = re.search(r'(?ms)^#if\s*0\s*\n.*cuda::device::experimental', t) is not None

if not already_disabled:
    t_new, n = pat_barrier.subn(
        "#if 0\n"
        "// Disabled for SCALE/AMD: no cuda::device::experimental barrier needed.\n"
        "// namespace cde = cuda::device::experimental;\n"
        "// using barrier_t = cuda::barrier<cuda::thread_scope_block>;\n"
        "#endif\n",
        t
    )
    if n:
        t = t_new
        changed = True
        print(f"Disabled barrier alias block ({n} occurrence).")
    else:
        print("Barrier alias block not found; no changes made.")
else:
    print("Barrier alias block already disabled; skipping.")

if changed and t != t0:
    p.write_text(t)
    print("Patch applied.")
else:
    print("No changes written.")
PY
