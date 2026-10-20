#!/usr/bin/env bash
# Helper for the verify-dependencies skill. Builds one thirdparty project in a
# scale-test-<distro> container to find the system packages it needs.
#
# Usage: verify.sh <command> <project> [args...]
#   setup <project> <sha>       Start the build container, with the SCALE nightly package
#                               from packages/nightlies/<sha>/<distro>/ and the project's
#                               current .dependencies installed.
#   build <project>             Wipe the project's workdir and run its build stage.
#                               Prints the log path, exit code and likely errors.
#   errors <project>            Print likely missing-dependency lines from the last log.
#   install <project> <entry>.. Install `<source>:<package>` entries into the container.
#                               Does not edit .dependencies.
#   whichpkg <file>             List the apt packages that provide a file (apt-file).
#   cleanup <project>           Remove the build container.
#
# Environment:
#   DISTRO      Distro to verify (default ubuntu24.04; only ubuntu24.04 is supported).
#   GPU_ARCH    Architecture to build for (default gfx1100). No GPU is needed to build.
set -euo pipefail
# Without this, a failure inside $(...) (e.g. the SCALE install in scale_image) is ignored.
shopt -s inherit_errexit

CMD="${1:?command required}"
shift

THIRDPARTY="$(realpath "$(dirname "$0")/../../..")"
SRC="$(realpath "${THIRDPARTY}/../..")"
DISTRO="${DISTRO:-ubuntu24.04}"
GPU_ARCH="${GPU_ARCH:-gfx1100}"
REGISTRY="docker-registry:53454"
BASE_IMAGE="${REGISTRY}/spectral/scale-test-${DISTRO}:latest"
APTFILE_IMAGE="verify-deps-aptfile-${DISTRO}"
LOG_DIR="${TMPDIR:-/tmp}/verify-deps"
WORKDIR="/tmp/thirdparty-tests"
export PATH="${HOME}/.local/bin:${PATH}"

if [[ "${DISTRO}" != ubuntu24.04 ]]; then
    echo "Only ubuntu24.04 is supported so far." >&2
    exit 1
fi

container() { echo "verify-deps-$(echo "$1" | tr '[:upper:]' '[:lower:]')-${DISTRO}"; }

# The scale-test images are on an http-only registry, which this docker daemon refuses.
# crane can pull from it, so pull with crane and load the result into docker.
pull_base() {
    docker image inspect "${BASE_IMAGE}" >/dev/null 2>&1 && return
    if ! command -v crane >/dev/null; then
        mkdir -p "${HOME}/.local/bin"
        curl -sSL https://github.com/google/go-containerregistry/releases/download/v0.20.2/go-containerregistry_Linux_x86_64.tar.gz |
            tar -xz -C "${HOME}/.local/bin" crane
    fi
    local tar
    tar="$(mktemp)"
    crane pull --insecure "${BASE_IMAGE}" "${tar}"
    docker load -i "${tar}" >/dev/null
    rm -f "${tar}"
}

# An image with SCALE installed, cached per SCALE commit so later runs skip the install.
scale_image() {
    local sha="$1" image tmp
    image="verify-deps-scale-${DISTRO}:${sha:0:12}"
    if ! docker image inspect "${image}" >/dev/null 2>&1; then
        pull_base
        tmp="verify-deps-scale-install-$$"
        docker run --name "${tmp}" -v "${SRC}:/src:ro" "${BASE_IMAGE}" bash -c "
            set -e
            /src/scripts/install-from-artefacts.sh packages/nightlies/${sha}/${DISTRO}/
            test -e /opt/scale" >&2
        docker commit "${tmp}" "${image}" >/dev/null
        docker rm "${tmp}" >/dev/null
    fi
    echo "${image}"
}

# Install `<source>:<package>` entries, the same way image_graph.py's dockerfiles do.
install_entries() {
    local c="$1" entry source package
    shift
    local apt=() pip=() pipx=()
    for entry in "$@"; do
        source="${entry%%:*}"
        package="${entry#*:}"
        case "${source}" in
            apt) apt+=("${package}") ;;
            pip) pip+=("${package}") ;;
            pipx) pipx+=("${package}") ;;
            ext)
                docker exec "${c}" sudo /src/test/thirdparty/images/install-ext.sh "${package}"
                ;;
            *)
                echo "Unsupported source for ${DISTRO}: ${entry}" >&2
                exit 1
                ;;
        esac
    done
    if [[ ${#apt[@]} -gt 0 ]]; then
        docker exec -e DEBIAN_FRONTEND=noninteractive "${c}" bash -c \
            'sudo -E apt-get install -y -qq "$@" >/dev/null' _ "${apt[@]}"
    fi
    if [[ ${#pip[@]} -gt 0 ]]; then
        docker exec "${c}" sudo PIP_BREAK_SYSTEM_PACKAGES=1 pip3 install -q "${pip[@]}"
    fi
    if [[ ${#pipx[@]} -gt 0 ]]; then
        docker exec "${c}" sudo PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install "${pipx[@]}"
    fi
}

errors() {
    # Lines that usually mean something is missing. Deduplicated, oldest first.
    grep -aE \
        -e 'Could NOT find' \
        -e 'Could not find a package configuration file' \
        -e 'No package .* found' \
        -e 'Package .* was not found' \
        -e 'fatal error: .*: No such file or directory' \
        -e 'cannot find -l' \
        -e 'command not found' \
        -e '(Program|Dependency) .* not found' \
        -e 'No module named' \
        -e 'configure: error:' \
        -e 'CMake Error' \
        -e 'not found in PATH' \
        -e 'Unable to find' \
        -e '[Nn]o such file or directory' \
        "$1" | sed -E 's/\x1b\[[0-9;]*m//g' | awk '!seen[$0]++' | head -40 || true
}

case "${CMD}" in
setup)
    PROJECT="${1:?project required}"
    SHA="${2:?SCALE commit sha required}"
    C="$(container "${PROJECT}")"
    IMAGE="$(scale_image "${SHA}")"
    docker rm -f "${C}" >/dev/null 2>&1 || true
    docker run -d --name "${C}" -v "${SRC}:/src:ro" "${IMAGE}" sleep infinity >/dev/null
    docker exec "${C}" bash -c 'sudo apt-get update -qq 2>&1 | grep -v scale-dist || true'
    mapfile -t ENTRIES < <(grep -E "^${DISTRO}:" "${THIRDPARTY}/${PROJECT}/.dependencies" | cut -d: -f2-)
    if [[ ${#ENTRIES[@]} -gt 0 ]]; then
        install_entries "${C}" "${ENTRIES[@]}"
    fi
    echo "Container ${C} ready, with: ${ENTRIES[*]:-(nothing extra)}"
    ;;
build)
    PROJECT="${1:?project required}"
    C="$(container "${PROJECT}")"
    mkdir -p "${LOG_DIR}"
    LOG="${LOG_DIR}/${PROJECT}-${DISTRO}.log"
    # Build scripts are not rerunnable (e.g. `mkdir build`), so always start fresh.
    # thirdparty-tests.sh also builds openmpi first for the projects that need it.
    set +e
    docker exec \
        -e THIRDPARTY_TEST="${PROJECT}" -e THIRDPARTY_TEST_ACTION=build \
        -e THIRDPARTY_TEST_ARCH="${GPU_ARCH}" -e INSTALL_PATH=/opt/scale \
        -e THIRDPARTY_TEST_PATH="${WORKDIR}" \
        "${C}" bash -c "rm -rf ${WORKDIR}/${PROJECT} ${WORKDIR}/openmpi && /src/scripts/thirdparty-tests.sh" \
        >"${LOG}" 2>&1
    RC=$?
    set -e
    echo "log: ${LOG}"
    echo "exit: ${RC}"
    if [[ ${RC} -ne 0 ]]; then
        echo "--- likely errors"
        errors "${LOG}"
        echo "--- last lines"
        sed -E 's/\x1b\[[0-9;]*m//g' "${LOG}" | tail -15
    fi
    ;;
errors)
    PROJECT="${1:?project required}"
    errors "${LOG_DIR}/${PROJECT}-${DISTRO}.log"
    ;;
install)
    PROJECT="${1:?project required}"
    shift
    install_entries "$(container "${PROJECT}")" "$@"
    ;;
whichpkg)
    FILE="${1:?file required}"
    if ! docker image inspect "${APTFILE_IMAGE}" >/dev/null 2>&1; then
        docker rm -f "${APTFILE_IMAGE}" >/dev/null 2>&1 || true
        docker run --name "${APTFILE_IMAGE}" "ubuntu:${DISTRO#ubuntu}" bash -c \
            'apt-get update -qq && apt-get install -y -qq apt-file && apt-file update' >/dev/null 2>&1
        docker commit "${APTFILE_IMAGE}" "${APTFILE_IMAGE}" >/dev/null
        docker rm "${APTFILE_IMAGE}" >/dev/null
    fi
    docker run --rm "${APTFILE_IMAGE}" apt-file search -- "${FILE}" | head -20
    ;;
cleanup)
    PROJECT="${1:?project required}"
    docker rm -f "$(container "${PROJECT}")" >/dev/null 2>&1 || true
    ;;
*)
    echo "Unknown command: ${CMD}" >&2
    exit 1
    ;;
esac
