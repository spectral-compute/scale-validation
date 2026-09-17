#!/bin/bash
#
# Switch on the unit test suite that 04-test.sh runs, and fix three upstream
# bugs that break it. The bugs are all present in v9.2.0 and still in upstream
# master (c6818209a, 2026-08-25); none of them involve SCALE, they are just
# latent in CPU code that upstream never runs (see the harness patch below).

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# cs_check_cdo dies with SIGSEGV in the HHO face basis setup.
#
# _add_tria_to_covariance() declares a single double for the quadrature weight
# and passes its address, but cs_quadrature_tria_3pts() fills three:
#
#   w[0] = w[1] = w[2] = _quad_over3 * area;   (cs_quadrature.cpp)
#
# so the callee writes 16 bytes past the end of the object. The prototype still
# advertises the old single-weight contract ("double *w", cs_quadrature.h), and
# the other two callers in cs_basis_func.cpp pass a real array and then
# needlessly replicate weights[0] into [1] and [2] -- leftovers from before the
# callee grew to write all three. Only this call site was missed.
#
# Whether the overflow is harmless depends on the frame layout. g++ happens to
# get away with it; SCALE places the weight immediately below gpts, so w[2]
# lands on gpts[0][0] and the corrupt Gauss point propagates into the face
# basis axes until the run walks off cm->xv with a garbage vertex index. The fix
# mirrors _add_tetra_to_inertia3() a few lines below, which already takes an
# array and reads element 0.
patch -p1 -d code_saturne < "${SCRIPT_DIR}/patches/cs_scheme_geometry_quadrature_weights.patch"

# fvm_selector_postfix_test doesn't compile: "fatal error: 'cs_defs.h' file not
# found". Two includes were never updated for the 9.x header reshuffle into
# src/base -- "cs_defs.h" should be "base/cs_defs.h" (the file gets it right
# further down), and "basr/cs_mem.h" is a typo for "base/".
patch -p1 -d code_saturne < "${SCRIPT_DIR}/patches/fvm_selector_postfix_test_includes.patch"

# fvm_selector_test exits 127: no such binary.
#
# Its rule in tests/Makefile.am compiles fvm_selector_test.cpp but names the
# output after its sibling ("-o fvm_selector_postfix_test"), so the program is
# never created under the name the test harness looks for. Nothing catches it:
# the recipe exits 0, and make does not check that a non-phony target's file
# actually appeared, so "make check" reports success.
#
# Introduced in 53b288054 (2023-10-16), which converted both fvm_selector tests
# from automake link rules to explicit cs_compile_build.py recipes -- needed
# after 811d4f36f pulled their link closure up to the full solver -- and wrote
# the new fvm_selector_test rule as a copy of the postfix one.
#
# This also has to be fixed for the include patch above to buy anything: both
# rules write to the same path and neither declares a prerequisite, so they
# re-run on every "make check" and race under -j. Whichever lands last is what
# automake then runs as "fvm_selector_postfix_test".
patch -p1 -d code_saturne < "${SCRIPT_DIR}/patches/fvm_selector_test_output_name.patch"

# Upstream ships the unit tests with automake's test harness switched off:
# tests/Makefile.am has "#TESTS=$(check_PROGRAMS)", so "make check" compiles the
# test programs but never runs them -- which is why the three bugs above went
# unnoticed upstream. Switch it on so "make check" reports PASS/FAIL per test
# and captures each one's output to tests/<name>.log, and declare bft_error_test
# an expected failure.
patch -p1 -d code_saturne < "${SCRIPT_DIR}/patches/enable_test_harness.patch"
