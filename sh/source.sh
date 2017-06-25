# shellcheck shell=sh

# Taken from bash-script-template and made compatible with plain sh
# Original code at: https://github.com/ralish/bash-script-template

# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
build_path() {
    if [ -z "${1-}" ] || [ $# -gt 2 ]; then
        printf "Invalid arguments passed to build_path()!"
        exit 2
    fi

    temp_path="$1:"
    if [ -n "${2-}" ]; then
        temp_path="$temp_path$2:"
    fi

    new_path=''
    while [ -n "$temp_path" ]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
            *:"$path_entry":*) ;;
                            *) new_path="$new_path:$path_entry"
                               ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    build_path="${new_path#:}"

    unset new_path path_entry temp_path
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
