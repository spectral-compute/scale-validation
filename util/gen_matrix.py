# This is a script we use internally to tell our CI:
#   - what to run
#   - what we expect to fail
#   - what stage we expect it to fail at (build or run)
# It's probably not useful to you if you don't work at spectral
# See also: README_INTERNAL.md

import json
import os
from pathlib import Path

REPO_BASE = Path.cwd()
IGNORE_LIST = [".jj", ".forgejo", ".git", "util", ".claude"]

ISAS = json.loads(os.environ["ISAS"])

should_build = set()
should_run = set()
xfail_build = set()
xfail_run = set()
for subdir in REPO_BASE.iterdir():
    if not subdir.is_dir():
        print(f"skip : {subdir} - not directory")
        continue

    if subdir.name in IGNORE_LIST:
        print(f"skip : {subdir} - in ignore list")
        continue

    if (subdir / ".skip-ci").is_file():
        print(f"skip : {subdir} - .skip-ci file exists")
        continue

    name = subdir.name
    print(f"build: {name}")
    should_build.add(name)
    if (subdir / ".build-fails").is_file():
        print(f"xfail: {name} - .build-fails file exists")
        xfail_build.add(name)

    if (subdir / ".run-fails").is_file():
        print(f"xfail: {name} - .run-fails file exists")
        xfail_run.add(name)

    for isa in ISAS:
        if (subdir / f".build-fails-on-{isa}").is_file():
            xfail_build.add((name, isa))

        if (subdir / f".run-fails-on-{isa}").is_file():
            xfail_run.add((name, isa))

    if not (subdir / ".build-only").is_file():
        print(f"run  : {name}")
        should_run.add(name)
    else:
        print(f"norun: {name} - .build-only file exists")

matrix = list(
    [
        {
            "target": target,
            # Note: If building is expected to fail but succeeds, we won't
            # actually end up running things anyway because of forgejo lacking proper
            # understanding of xfails
            # So we just don't bother creating the run step, to avoid confusion
            "should_run": target in should_run and target not in xfail_build,
            "xfail_build": target in xfail_build or (target, isa) in xfail_build,
            "xfail_run": (
                target in xfail_build
                or target in xfail_run
                or (target, isa) in xfail_build
                or (target, isa) in xfail_run
            ),
            "isa": isa,
        }
        for target in should_build
        for isa in ISAS
    ]
)


print("---")
print(f"building {len(should_build)} projects")
print(f"running {len(should_build)} projects")

with open(os.environ["FORGEJO_OUTPUT"], "a") as out:
    out.write(f"matrix={json.dumps(matrix)}\n")
