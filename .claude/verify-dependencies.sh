#!/usr/bin/env bash
# Run the verify-dependencies skill for one project in a fresh Docker sandbox.
# Run this on the host, not inside a sandbox. Needs the `sbx` CLI.
#
# Usage: verify-dependencies.sh <project> <scale-sha> [distro]
#
# Creates a sandbox for the SCALE checkout that contains this test/thirdparty directory,
# gives it the network access the builds need, runs Claude non-interactively with the
# skill, and removes the sandbox afterwards. The skill edits <project>/.dependencies in
# place, so the result appears in your checkout.
#
# Environment:
#   KEEP=1          Keep the sandbox afterwards, to inspect it with `sbx exec -it <name> bash`.
#   SBX_CPUS, SBX_MEMORY
#                   Passed to `sbx create --cpus` and `--memory`.
#   SBX_DOCKER_SIZE Size of the sandbox's docker storage (/var/lib/docker). Default 60g.
#                   The scale-test image with SCALE installed takes about 7.5 GB, and the
#                   project's build happens inside it, so the 10g sbx default is too small.
#   ALLOW_NETWORK   Comma-separated hosts this sandbox may reach. Default: everything
#                   ("**"), because builds download from many places (GitHub, PyPI,
#                   project mirrors, model hubs). The rule applies only to this sandbox.
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
    sed -n '5p' "$0" >&2
    exit 1
fi
PROJECT="$1"
SHA="$2"
DISTRO="${3:-ubuntu24.04}"

THIRDPARTY="$(realpath "$(dirname "$0")/..")"
SCALE="$(realpath "${THIRDPARTY}/../..")"
if [[ ! -f "${THIRDPARTY}/${PROJECT}/.dependencies" ]]; then
    echo "No ${THIRDPARTY}/${PROJECT}/.dependencies" >&2
    exit 1
fi

# Sandbox names allow letters, numbers, hyphens and periods.
NAME="verify-deps"

# Internal hosts: the SCALE nightly packages and the scale-test images.
INTERNAL="artefacts-dl.spectral.vpn,docker-registry:53454"

# A local deny rule beats any allow rule, so check for one before starting.
if sbx policy ls 2>/dev/null | grep -E 'deny' | grep -qE 'artefacts-dl\.spectral\.vpn|docker-registry'; then
    echo "A deny rule blocks an internal host this needs. Find it with 'sbx policy ls' and" >&2
    echo "remove it, e.g. 'sbx policy rm network --resource artefacts-dl.spectral.vpn'." >&2
    exit 1
fi

if ! sbx ls 2>/dev/null | grep -qw "${NAME}"; then
    echo "creating"
    CREATE=(--name "${NAME}")
    [[ -n "${SBX_CPUS:-}" ]] && CREATE+=(--cpus "${SBX_CPUS}")
    [[ -n "${SBX_MEMORY:-}" ]] && CREATE+=(--memory "${SBX_MEMORY}")
    # Mount test/thirdparty separately too, like sbxenv.yaml does, since it is a submodule.
    # DOCKER_SANDBOXES_DOCKER_SIZE sets the docker storage size for this sandbox only. It
    # only has an effect when the sandbox is created.
    DOCKER_SANDBOXES_DOCKER_SIZE="${SBX_DOCKER_SIZE:-60g}" \
        sbx create "${CREATE[@]}" claude "${SCALE}" "${THIRDPARTY}"

    sbx run --name "${NAME}" -- /login
fi

cleanup() {
    echo "Kept sandbox ${NAME}. Remove it with 'sbx rm -f ${NAME}'."
}
trap cleanup EXIT

sbx policy allow network --sandbox "${NAME}" "${INTERNAL}"
sbx policy allow network --sandbox "${NAME}" "${ALLOW_NETWORK:-**}"

PROMPT="Use the verify-dependencies skill in ${THIRDPARTY}/.claude/skills/verify-dependencies/SKILL.md \
to verify ${PROJECT}/.dependencies for ${DISTRO}, with SCALE commit ${SHA}. \
Work from ${THIRDPARTY}. Follow the skill exactly and end with its report."

sbx run --name "${NAME}" -- "${PROMPT}"
