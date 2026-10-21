"""Treat test failures caused only by Triton as expected.

Triton compiles kernels to NVIDIA binaries, which can't run under SCALE, so any
test whose kernel is written in Triton fails to launch it. This turns exactly
those failures into expected failures, for both unittest (via sitecustomize)
and pytest (as a plugin, via PYTEST_PLUGINS), and appends each one to the file
named by SCALE_TRITON_XFAIL_LOG. Every other failure still fails.
"""

import json
import os
import traceback

REASON = "Triton kernels can't run under SCALE"

# Triton's own errors: its NVIDIA binaries failing to load (directly, or via
# torch.compile's Inductor), or its compiler rejecting a kernel for the device.
_MESSAGES = (
    "Triton Error [CUDA]: invalid image",
    "CUDA driver error: invalid image",
    "triton.runtime.errors.OutOfResources",
)
_TRITON_FRAMES = ("/triton/", "/torch/_inductor/")


def is_triton_failure(exc_type, exc, tb):
    """Whether an exception is one of Triton's, raised from Triton's code."""
    if exc is None:
        return False
    text = "".join(traceback.format_exception(exc_type, exc, tb))
    if not any(m in text for m in _MESSAGES):
        return False
    frames = traceback.extract_tb(tb) if tb else []
    for cause in (exc.__cause__, exc.__context__):
        if cause is not None and cause.__traceback__ is not None:
            frames += traceback.extract_tb(cause.__traceback__)
    return any(t in f.filename for f in frames for t in _TRITON_FRAMES)


# The last Triton load failure during the current test, even if the code under
# test caught it (e.g. to fall back from a fused path, which the test then
# finds wasn't taken).
_caught = None


def _watch_triton():
    """Record Triton's binary-load failures, which callers may swallow."""
    try:
        # Import it now: tests often first import Triton during the test.
        import triton.compiler.compiler as compiler
    except ImportError:
        return
    original = compiler.CompiledKernel._init_handles
    if getattr(original, "_scale_watched", False):
        return

    def init_handles(self, *args, **kwargs):
        global _caught
        try:
            return original(self, *args, **kwargs)
        except Exception as e:
            if any(m in str(e) for m in _MESSAGES):
                _caught = str(e)
            raise

    init_handles._scale_watched = True
    compiler.CompiledKernel._init_handles = init_handles


def _start_test():
    global _caught
    _caught = None
    _watch_triton()


def _expected(err):
    """Whether a failure is Triton's: its own error, or any failure after a
    Triton kernel failed to load during the test."""
    return is_triton_failure(*err) or _caught is not None


def _log(test_id, exc):
    path = os.environ.get("SCALE_TRITON_XFAIL_LOG")
    if not path:
        return
    triton = is_triton_failure(type(exc), exc, exc.__traceback__)
    message = str(exc if triton or _caught is None else _caught).strip()
    entry = {
        "test": test_id,
        "kind": "raised" if triton else "caught",
        "error": message.splitlines()[0][:200] if message else "",
    }
    with open(path, "a") as f:
        f.write(json.dumps(entry) + "\n")


def patch_unittest():
    import unittest

    result = unittest.TestResult

    def wrap(name):
        original = getattr(result, name)

        def handler(self, test, err):
            if _expected(err):
                _log(test.id(), err[1])
                self.addExpectedFailure(test, err)
            else:
                original(self, test, err)

        setattr(result, name, handler)

    wrap("addError")
    wrap("addFailure")

    original_start = result.startTest

    def start_test(self, test):
        _start_test()
        original_start(self, test)

    result.startTest = start_test

    original_subtest = result.addSubTest

    def add_subtest(self, test, subtest, err):
        if err is not None and _expected(err):
            _log(subtest.id(), err[1])
            self.addExpectedFailure(subtest, err)
        else:
            original_subtest(self, test, subtest, err)

    result.addSubTest = add_subtest


# pytest plugin hooks. pytest only imports this module as a plugin, so these
# are inert under unittest.
try:
    import pytest
except ImportError:
    pytest = None

if pytest is not None:

    @pytest.hookimpl(tryfirst=True)
    def pytest_runtest_setup(item):
        _start_test()

    @pytest.hookimpl(hookwrapper=True)
    def pytest_runtest_makereport(item, call):
        outcome = yield
        report = outcome.get_result()
        if report.failed and call.excinfo is not None:
            e = call.excinfo
            if _expected((e.type, e.value, e.tb)):
                _log(item.nodeid, e.value)
                report.outcome = "skipped"
                report.wasxfail = REASON
