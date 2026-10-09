#!/usr/bin/env bash
# Build a docker image, and push it if PUSH_IMAGE=1.
# Usage: mkImage.sh <dockerfile> [--] [extra args to docker build]
# The image is named after the dockerfile, without the `.dockerfile` suffix, and the
# directory containing the dockerfile is the build context.
. "$(dirname "$0")"/prelude.sh

# Parse our arguments
DOCKERFILE="$1"
shift
if [[ "${1:-}" == "--" ]]; then
    shift
fi
IMAGE="$(basename "$DOCKERFILE" .dockerfile)"
CONTEXT="$(dirname "$DOCKERFILE")"

# The docker tag is latest in CI, otherwise the current username.
if [[ -z "${DOCKER_TAG:-}" ]]; then
    if [[ -n "${CI:-}" ]]; then
        DOCKER_TAG="latest"
    else
        DOCKER_TAG="$(whoami)"
    fi
fi

# Usually, the images we're basing things off of should be the same tag we're building now.
BASE_DOCKER_TAG="${BASE_DOCKER_TAG:-$DOCKER_TAG}"

# Our docker registry
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker-registry.spectral.vpn:53454}"
PRIVATE_DOCKER_REGISTRY="${DOCKER_PUSH:-$DOCKER_REGISTRY}/"

# Possibly deal with podman instead of docker
CONTAINER_RUNTIME=docker
EXTRA_ARGS=()
if which podman >/dev/null 2>&1; then
    CONTAINER_RUNTIME=podman
    EXTRA_ARGS+=(--format docker)
fi

if [[ "${CI:-0}${NO_CACHE:-0}" != "00" ]]; then
    EXTRA_ARGS+=(--no-cache)
fi

echo >&2 -e "::group::{\033[1mBuilding image ${IMAGE}:${DOCKER_TAG}\033[0m}"
"$CONTAINER_RUNTIME" build \
    --build-arg BASE_DOCKER_TAG="$BASE_DOCKER_TAG" \
    --build-arg PRIVATE_DOCKER_REGISTRY="$PRIVATE_DOCKER_REGISTRY" \
    -f "$DOCKERFILE" \
    -t "spectral/$IMAGE:$DOCKER_TAG" \
    "${EXTRA_ARGS[@]}" \
    "$@" \
    "$CONTEXT"
echo >&2 "::endgroup::"

# Also tag for the registry, so images based on this one can find it.
log "Adding additional tag $DOCKER_REGISTRY/spectral/$IMAGE:$DOCKER_TAG"
"$CONTAINER_RUNTIME" tag "spectral/$IMAGE:$DOCKER_TAG" "$DOCKER_REGISTRY/spectral/$IMAGE:$DOCKER_TAG"

if [[ "${PUSH_IMAGE:-}" == "1" ]]; then
    echo >&2 -e "::group::{\033[1mPushing to $DOCKER_REGISTRY/spectral/$IMAGE:$DOCKER_TAG\033[0m}"
    "$CONTAINER_RUNTIME" push "$DOCKER_REGISTRY/spectral/$IMAGE:$DOCKER_TAG"
    echo >&2 "::endgroup::"
fi
