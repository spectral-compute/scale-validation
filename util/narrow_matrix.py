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

reduced_matrix = list(
    x
    for x in ORIGINAL_MATRIX
    if (STAMPS_DIR / f"{x['target']}__{x['isa']}.ok").is_file() and x["should_run"]
)

with open(os.environ["FORGEJO_OUTPUT"], "a") as out:
    out.write(f"matrix={json.dumps(reduced_matrix)}\n")
