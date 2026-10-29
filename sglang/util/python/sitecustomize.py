# Loaded at startup by every Python process with this directory on PYTHONPATH,
# so that unittest-based SGLang tests treat Triton failures as expected; pytest
# loads the same module as a plugin, via PYTEST_PLUGINS.
import scale_triton_xfail

scale_triton_xfail.patch_unittest()
