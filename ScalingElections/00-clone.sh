#!/bin/bash
set -ETeuo pipefail
PIN_COMMIT="a7222a000edb9c2a4eb3dc5f97d2472785fa38c2" # Latest commit in master validated (there is no tags)

do_clone_hash ScalingElections https://github.com/ashvardanian/ScalingElections.git "${PIN_COMMIT}"
