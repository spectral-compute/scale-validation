# Script to help refactor old set version scripts into ones that read version.txt
# God forgive me...

insert_version () {

    local version_info=$(cat $1/version.txt)
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            continue
        fi
        read -r program version <<< "$line"
        # escape version strings for regex
        printf -v program "%q" "$program"
        printf -v version "%q" "$version"
        local clone_script="$(ls $1 -1 | grep -E 'clone|download')"

        sed -i -r 's/^(do_clone[^[:space:]]* '"$program"' [^[:space:]]+) '"$version"'$/\1 "$(cat "$(dirname $0)/version.txt" | grep "'"$program"'" | sed "s\/'"$program"' \/\/g")"/g' "$1/$clone_script"
    done <<< "$version_info"

}


for dir in $(dirname $0)/*; do
    if [[ -d "$dir" ]] && [[ -f "$dir/version.txt" ]]; then
        insert_version "$dir"
    fi
done
