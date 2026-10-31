#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Runs Ginkgo's own benchmark executables on generated stencil matrices (no downloads), in double
# precision. Each writes Ginkgo's JSON results; these are flattened into one CSV of
# "benchmark,case,path,seconds" rows, where path names the operation (and kernel component).
EXECUTOR=cuda
if [[ "${BENCHMARK_COMPILER:-}" == "hip" ]]; then
    EXECUTOR=hip
fi
PREFIX="${RESULTS_DIR:-$(realpath .)}/ginkgo.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S)"
B=build/benchmark

STENCILS='[{"size": 4000000, "stencil": "5pt"}, {"size": 2000000, "stencil": "7pt"}]'
STENCIL_7PT='[{"size": 1000000, "stencil": "7pt", "optimal": {"spmv": "csr"}}]'

# run <name> <executable> <input json> <args>...: a failing (or hung) benchmark loses only its own
# results.
function run() {
    local name="$1" exe="$2" input="$3"
    shift 3
    if ! echo "${input}" | timeout 1200 "${exe}" -executor "${EXECUTOR}" "$@" >"${PREFIX}.${name}.json"; then
        log "Benchmark ${name} failed"
        rm -f "${PREFIX}.${name}.json"
    fi
}

run spmv "${B}"/spmv/spmv "${STENCILS}" -formats csr,csri,csrm,coo,ell,sellp,hybrid
run blas "${B}"/blas/blas '[{"n": 16000000}]' -operations copy,axpy,scal,dot,norm,prefix_sum32
run gemm "${B}"/blas/blas '[{"n": 2048}]' -operations gemm
run conversion "${B}"/conversion/conversion "${STENCIL_7PT}" -formats csr,coo,ell,sellp,hybrid
run sparse_blas "${B}"/sparse_blas/sparse_blas "${STENCIL_7PT}" -operations spgemm,spgeam,transpose,sort
# -detailed=false: don't record the residual at every iteration (slow, and not what's being measured).
run solver "${B}"/solver/solver "${STENCIL_7PT}" -solvers cg,fcg,cgs,bicgstab,gmres \
    -preconditioners none,jacobi -max_iters 200 -rel_res_goal 0 -repetitions 3 -detailed=false
run preconditioner "${B}"/preconditioner/preconditioner "${STENCIL_7PT}" \
    -preconditioners jacobi,ilu,parilu,parilut,ic,paric,isai -detailed=false

python3 - "${PREFIX}" <<'PY'
import glob, json, sys

prefix = sys.argv[1]
rows = []


def walk(bench, case, path, node):
    if isinstance(node, dict):
        if isinstance(node.get("time"), (int, float)) and node.get("completed", True) is not False:
            rows.append((bench, case, "/".join(path), node["time"]))
        for k, v in node.items():
            if k == "components" and isinstance(v, dict):
                for c, t in v.items():
                    rows.append((bench, case, "/".join(path + [c]), t))
            elif isinstance(v, dict):
                walk(bench, case, path + [k], v)


for f in sorted(glob.glob(prefix + ".*.json")):
    bench = f[len(prefix) + 1:-len(".json")]
    for case in json.load(open(f)):
        name = case.get("stencil", case.get("filename", "")) + str(case.get("size", case.get("n", "")))
        for key in ("spmv", "blas", "conversion", "sparse_blas", "solver", "preconditioner"):
            if key in case:
                walk(bench, name, [], case[key])

with open(prefix + ".csv", "w") as out:
    out.write("benchmark,case,path,seconds\n")
    for r in rows:
        out.write(",".join(map(str, r)) + "\n")
if not rows:
    sys.exit("No benchmark results")
print(f"{len(rows)} results in {prefix}.csv")
PY
