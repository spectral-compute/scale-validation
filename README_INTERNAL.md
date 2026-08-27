# scale-validation internal docs

> Note: This information is public, but is probably not useful to you if you don't work on SCALE

## What CI runs

CI decides what to run by calling `util/gen_matrix.py`. The logic of that is:

  - Any subfolder that isn't listed in `IGNORE_LIST` is considered a test we might want to run.
  - If `subfolder/.skip-ci` exists, don't do anything with the test.
  - If `subfolder/.build-only` exists, there is nothing useful to run after it's done building.
  - If `subfolder/.build-fails` or `subfolder/.run-fails` exists, then we expect either building or running to fail.
  - Similarly, if `subfolder/.build-fails-on-$ISA` or `subfolder/.run-fails-on-$ISA` exists, then we expect either building or running to fail only for that specific ISA.

You can debug this with the following one-liner:

```
export FORGEJO_OUTPUT=$(mktemp) && echo "" > $FORGEJO_OUTPUT && ISAS='["gfx1100", "sm_120"]' python util/gen_matrix.py && (cat $FORGEJO_OUTPUT | cut -c 8- | jq .)
```

When invoking the extended test workflow, you can also specify a regex to match the names of targets against. The name of a test must fully match the regex in order to run.

After all build steps are completed, we run `narrow_matrix.py` to narrow down the matrix to only ones whose build phase actually succeeded, and who have test scripts to run.
This is needed due to limitations in forgejo - see #1182 internally.
