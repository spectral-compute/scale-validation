#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Download the full source package, which includes all test data, rather than the git repo
VERSION="$(get_version arrayfire)"
mkdir arrayfire
curl -L "https://github.com/arrayfire/arrayfire/releases/download/$VERSION/arrayfire-full-${VERSION#v}.tar.bz2" | tar -xjf - --strip-components=1 -C arrayfire
