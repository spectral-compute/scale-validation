#!/usr/bin/env bash
# shellcheck disable=SC2076
set -euo pipefail

ALLOWED_TARGETS=("devel" "runtime" "base")
ALLOWED_DISTROS=("rocky9" "ubuntu22.04" "ubuntu24.04")
ALLOWED_CUDA_VERSIONS=("13.0.2" "12.1.0" "11.8.0" "11.4.3")

usage() {
	echo "Usage: $0 <target> <distro> <version>"
	echo "  target:  ${ALLOWED_TARGETS[*]}"
	echo "  distro:  ${ALLOWED_DISTROS[*]}"
	echo "  version: ${ALLOWED_CUDA_VERSIONS[*]}"
	exit 1
}

TARGET="${1:-}"
DISTRO="${2:-}"
CUDA_VERSION="${3:-}"

[[ -z "$TARGET" || -z "$DISTRO" || -z "$CUDA_VERSION" ]] && usage

validate() {
	local value="$1"
	shift
	local allowed=("$@")
	if [[ ! "${allowed[*]}" =~ "${value}" ]]; then
		echo "Error: '${value}' is not allowed. Choose from: ${allowed[*]}"
		return 1
	fi
}

ok=true
validate "$TARGET" "${ALLOWED_TARGETS[@]}" || ok=false
validate "$DISTRO" "${ALLOWED_DISTROS[@]}" || ok=false
validate "$CUDA_VERSION" "${ALLOWED_CUDA_VERSIONS[@]}" || ok=false

[[ "$ok" == true ]] || exit 1

docker build \
	--build-arg TARGET="${TARGET}" \
	--build-arg DISTRO="${DISTRO}" \
	--build-arg CUDA_VERSION="${CUDA_VERSION}" \
	-t docker.io/spectralcompute/scale:"${CUDA_VERSION}-${TARGET}-${DISTRO}" \
	.
