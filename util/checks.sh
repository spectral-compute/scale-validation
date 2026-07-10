# Run a batch of independent checks inside one test script, continuing past
# individual failures so later checks still get a chance to run and report.
# The script's own exit code is decided at the end by check_exit, based on
# whether any check failed.
#
# Usage:
#   source "$(dirname "$0")/../util/checks.sh"
#   check_crack_md5() { ... }
#   check "crack MD5" check_crack_md5
#   check_exit
#
# Check functions with more than one sequential step should chain them with
# && (or an explicit "|| return 1"), rather than relying on `set -e`: bash
# suppresses errexit for the duration of a function called as an `if`/test
# condition, so an unchained early failure inside the function would silently
# continue on to later steps in that same check.

_CHECKS_TOTAL=0
_CHECKS_FAILED=0

check() {
    local label="$1"; shift
    _CHECKS_TOTAL=$(( _CHECKS_TOTAL + 1 ))
    echo -e "\x1b[1m--- ${label} ---\x1b[m"
    if "$@"; then
        echo -e "\x1b[32;1mPASS\x1b[m: ${label}"
    else
        echo -e "\x1b[31;1mFAIL\x1b[m: ${label}"
        _CHECKS_FAILED=$(( _CHECKS_FAILED + 1 ))
    fi
}

check_exit() {
    echo ""
    if [ "${_CHECKS_FAILED}" -gt 0 ]; then
        echo -e "\x1b[31;1m${_CHECKS_FAILED}/${_CHECKS_TOTAL} checks failed\x1b[m"
        exit 1
    fi
    echo -e "\x1b[32;1mAll ${_CHECKS_TOTAL} checks passed\x1b[m"
    exit 0
}
