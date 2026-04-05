# Two tiny helper functions for cloning things.

# TODO: This should be improved by checking if the version looks like a commit
# hash, and if so checking for later commits.
function check_recency() {
    local repo="$1"
    local ver="$2"

    # FIXME: This regex can be improved, it wouldn't match a version format of
    # just `vN`. But I cannot seen anything using that format in versions.txt
    # yet. The closest is gromacs, I think.
    if [[ "$ver" =~ ^v[[:digit:]]+\.[[:digit:]]+ ]]; then
        local patt="${ver//./[.]}\$" # escape '.' chars

        # Iterates tags starting with `v` from oldest to newest; when the tag
        # `ver` is recognised, `seen` is incremented for it and all later tags;
        # print `seen-1` to drop the increment from matching `ver`.
        local n=$(awk -v ver="$patt" 'seen || $NF ~ ver {seen++}; END {print seen-1}' \
            <(git ls-remote -t "$repo" v\*))

        echo "Version to clone is $n releases out of date"
    else
        echo "Unable to check version recency (unrecognisable branch/tag format)"
    fi
}

# Clone and sync submodules for a project.
function do_clone() {
  check_recency $2 $3
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
    echo $(cat "$dir/../versions.txt" | grep "$1 " | sed "s/$1 //g")
}
