#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone rodinia_suite https://github.com/manospavlidakis/rodinia_suite.git "$(get_version rodinia_suite)"
