#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh
source "$SCALE_VALIDATION/util/checks.sh"

# Run upstream's *-pdlp-no-presolve tests (see 02-test.sh), but accept an objective within a relative
# 1e-6 of upstream's expected digits. Commands and expected values come from ctest itself.
TESTS="$(ctest --test-dir build -R 'pdlp-no-presolve$' --show-only=json-v1 | python3 -c '
import json, sys
for t in json.load(sys.stdin)["tests"]:
    regex = next(p["value"][0] for p in t["properties"] if p["name"] == "PASS_REGULAR_EXPRESSION")
    print(t["name"], regex.split(":")[-1].strip(), *t["command"], sep="\t")
')"

check_instance() {
    local expected="$1"
    shift
    local actual
    # Like ctest's PASS_REGULAR_EXPRESSION, ignore the exit status: some instances end with a
    # non-optimal model status.
    actual="$({ "$@" || true; } | sed -n "s/^Objective value *: *//p")" &&
        echo "objective ${actual}, expected ${expected}..." &&
        python3 -c '
import sys
# Upstream gives only the leading digits of the mantissa, without the exponent.
actual, expected = float(sys.argv[1].split("e")[0]), float(sys.argv[2])
sys.exit(abs(actual - expected) > 1e-6 * abs(expected))
' "${actual}" "${expected}"
}

[ -n "${TESTS}" ]
while IFS=$'\t' read -r -a test; do
    check "${test[0]}" check_instance "${test[@]:1}"
done <<<"${TESTS}"

check_exit
