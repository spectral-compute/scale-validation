# This is a script we use internally to workaround a limitation in our CI
# It's probably not useful to you if you don't work at spectral
# See also: README_INTERNAL.md

import json
import os
from pathlib import Path

ORIGINAL_MATRIX = json.loads(
    os.environ["ORIGINAL_MATRIX"]
)  # the original output of gen_matrix.py, passed to forgejo's matrix.include
STAMPS_DIR = Path(
    os.environ["STAMPS_DIR"]
)  # directory containing all of our success stamps

def has_stamp(target: str, isa: str) -> bool:
    vendor = "nv" if isa.startswith("sm") else "amd"
    return (STAMPS_DIR / f"{target}__{vendor}.ok").is_file()

reduced_matrix = [
    {**x, "builds": [], "runs": valid_runs}
    for x in ORIGINAL_MATRIX
    if (
        valid_runs := [
            r for r in x["runs"] if has_stamp(x["target"], r["isa"]) and r["should_run"]
        ]
    )
]

with open(os.environ["FORGEJO_OUTPUT"], "a") as out:
    out.write(f"matrix={json.dumps(reduced_matrix)}\n")
