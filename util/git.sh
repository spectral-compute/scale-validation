#!/usr/bin/env bash
# Tiny helper functions for cloning things.

# Clone and sync submodules for a project.
do_clone() {
    if [[ -d "$1" ]]; then
        echo "WARNING: Source directory exists, so skipping git clone. You may have the wrong version."
        return 0
    fi

    if echo "$3" | grep -E '[a-zA-Z0-9]{40,64}' >/dev/null; then
        log "Checking out commit $3 of $2 into $1"
        git clone --recursive "$2" "$1"
        git -C "$1" checkout "$3"
        git -C "$1" submodule update --init --recursive
    else
        log "Checking out branch $3 of $2 into $1"
        git clone --recursive --depth 1 --shallow-submodules --branch "$3" "$2" "$1"
    fi
}

# Old name for when the above was two functions. Remove soon
do_clone_hash() {
    do_clone "$@"
}

# Extract version from scale-validation's version.txt
get_version() {
    cat "$SCALE_VALIDATION/versions.txt" | grep "$1 " | sed "s/$1 //g"
}
