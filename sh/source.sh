# shellcheck shell=sh

# Taken from bash-script-template and made compatible with plain sh
# Original code at: https://github.com/ralish/bash-script-template

# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
#       $3 (optional): Set to any value to add the path(s) provided in the
#                      first argument to the start of the constructed list of
#                      paths, removing any duplicate paths which already were
#                      present in the path string. If unset, the paths will be
#                      added only if they did not already exist in the list of
#                      paths in the second argument, preserving the existing
#                      ordering of paths. If a path is present multiple times
#                      in the second argument the first instance of the path
#                      will be used, and subsequent instances are removed.
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
build_path() {
    if [ -z "${1-}" ] || [ $# -gt 3 ]; then
        printf "Invalid arguments passed to build_path()!"
        exit 2
    fi

    first_path="$1"
    second_path="${2-}"
    prioritise_first="${3-}"

    # Join the paths if two arguments were provided
    temp_path="$first_path:"
    if [ -n "$second_path" ]; then
        # If we're not going to prioritise paths in the first argument we need
        # to remove the paths which are already present in the second argument.
        if [ -z "$prioritise_first" ]; then
            new_path=''

            while [ -n "$temp_path" ]; do
                # Grab the next path element from the first path argument
                path_entry="${temp_path%%:*}"

                # Add the path if it's not present in the second path argument
                case ":$second_path:" in
                    *:"$path_entry":*) ;;
                                    *)
                                       new_path="$new_path:$path_entry"
                                       ;;
                esac

                # Remove processed path element
                temp_path="${temp_path#*:}"
            done

            # Remove leading colon from and add trailing colon to the updated
            # first argument paths.
            temp_path="${new_path#:}:"
        fi

        temp_path="$temp_path$second_path:"
    fi

    # Now loop over the path elements in the combined arguments (or just the
    # first argument if no second argument was provided) and remove duplicates.
    new_path=''
    while [ -n "$temp_path" ]; do
        # Grab the next path element
        path_entry="${temp_path%%:*}"

        # Add the path if it's not present
        case ":$new_path:" in
            *:"$path_entry":*) ;;
                            *)
                               new_path="$new_path:$path_entry"
                               ;;
        esac

        # Remove processed path element
        temp_path="${temp_path#*:}"
    done

    # Remove leading colon from the final list of paths
    # shellcheck disable=SC2034
    build_path="${new_path#:}"

    unset new_path path_entry temp_path
    unset first_path second_path prioritise_first
}

# DESC: Evaluates a command and logs if the app config will be loaded
# ARGS: $1 (required): Name of the application (for log output)
#       $2 (required): Command to evaluate to determine if config shoud load
# OUTS: None
# NOTE: Logging only occurs if the DOTFILES_LOG variable is true.
df_app_load() {
    if [ $# -ne 2 ]; then
        printf "Invalid arguments passed to df_app_load()!"
        exit 2
    fi

    if eval "$2"; then
        df_log "Loading app configuration: $1"
        return 0
    fi

    df_log "Skipping app configuration: $1"
    return 1
}

# DESC: Outputs a log entry to stdout
# ARGS: $1 (required): Message to log
# OUTS: None
# NOTE: Logging only occurs if the DOTFILES_LOG variable is true.
df_log() {
    if [ $# -ne 1 ]; then
        printf "Invalid arguments passed to df_log()!"
        exit 2
    fi

    # shellcheck disable=SC2154
    if [ "$DOTFILES_LOG" = 'true' ]; then
        echo "[dotfiles] $1"
    fi
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
