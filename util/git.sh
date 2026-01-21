# Two tiny helper functions for cloning things.

# Clone and sync submodules for a project.
function do_clone() {
  git clone --recursive --depth 1 --shallow-submodules --branch $3 $2 $1
}

# Slower, but allows random hashes.
function do_clone_hash() {
  git clone --recursive $2 $1
  git -C $1 checkout $3
  git -C $1 submodule update --init --recursive
}

# Extract version from matching version.txt
get_version () {
    local dir=""
    if [[ $# == 1 ]]; then
        dir="$(dirname $0)"
    else
        dir="$2"
    fi
    echo $(cat "$dir/../versions.txt" | grep "$1" | sed "s/$1 //g")
}
