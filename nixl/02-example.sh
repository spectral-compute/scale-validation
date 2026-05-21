#!/bin/bash
#
# Run NIXL's bundled C++ example end-to-end and confirm it reports a
# completed transfer.

set -ETeuo pipefail

# Point NIXL's plugin manager at the freshly-built UCX backend.
NIXL_PLUGIN_DIR="$(realpath nixl/build/src/plugins/ucx)"
export NIXL_PLUGIN_DIR

# The UCX library NIXL was built against lives in our local install, not
# the system path. Make sure the loader can find it at runtime.
LD_LIBRARY_PATH="$(realpath ucx-install/lib):${LD_LIBRARY_PATH-}"
export LD_LIBRARY_PATH

# Run NIXL's bundled example, capturing output for inspection.
./nixl/build/examples/cpp/nixl_example 2>&1 | tee test.log

# The example prints "Test done" on a successful end-to-end transfer.
# Absence of that line means the run failed, even if the program exited
# cleanly.
if ! grep -q "Test done" test.log; then
  echo "Error: NIXL example did not print 'Test done' — see test.log." >&2
  exit 1
fi
