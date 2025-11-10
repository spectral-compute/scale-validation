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
t0 = p.read_text(encoding="utf-8")
t = t0
changed = False

# ---------------------------------------------------------------------
# 1) Disable ONLY the barrier alias block:
#    #if !defined(SCALING_ELECTIONS_WITH_HIP)
#    namespace cde = cuda::device::experimental;
#    using barrier_t = cuda::barrier<cuda::thread_scope_block>;
#    #endif
# ---------------------------------------------------------------------
pat_barrier = re.compile(
    r'(?ms)^#if\s*!defined\s*\(\s*SCALING_ELECTIONS_WITH_HIP\s*\)\s*'
    r'\n\s*namespace\s+cde\s*=\s*cuda::device::experimental\s*;\s*'
    r'\n\s*using\s+barrier_t\s*=\s*cuda::barrier\s*<\s*cuda::thread_scope_block\s*>\s*;\s*'
    r'\n\s*#endif\s*'
)

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

# ---------------------------------------------------------------------
# 2) Insert `error = cudaDeviceSynchronize();` right AFTER the line:
#    cudaMemset(strongest_paths_ptr, 0,
#               num_candidates * num_candidates * sizeof(votes_count_t));
#    (Only if it's not already followed by that call.)
# ---------------------------------------------------------------------
pat_memset_sync = re.compile(
    r'(?m)^(?P<indent>\s*)(?P<call>cudaMemset\(\s*strongest_paths_ptr\s*,\s*0\s*,\s*'
    r'num_candidates\s*\*\s*num_candidates\s*\*\s*sizeof\(\s*votes_count_t\s*\)\s*\)\s*;\s*)'
    r'(?!\n\s*error\s*=\s*cudaDeviceSynchronize\(\)\s*;)',  # do nothing if already present
)

def _insert_sync(m: re.Match) -> str:
    return f"{m.group('indent')}{m.group('call')}\n{m.group('indent')}error = cudaDeviceSynchronize();"

t_new, n = pat_memset_sync.subn(_insert_sync, t)
if n:
    t = t_new
    changed = True
    print(f"Inserted cudaDeviceSynchronize() after strongest_paths cudaMemset ({n} occurrence).")
else:
    print("Target cudaMemset line not found or already synchronized; no changes made.")

# ---------------------------------------------------------------------
# Write back if anything changed
# ---------------------------------------------------------------------
if changed and t != t0:
    p.write_text(t, encoding="utf-8")
    print("Patch applied.")
else:
    print("No changes written.")
PY
