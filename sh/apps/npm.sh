# shellcheck shell=sh

# npm configuration
if command -v npm > /dev/null; then
    # Add the npm man pages to our MANPATH
    npm_global_root="$(npm root -g)"
    npm_global_man="$npm_global_root/npm/man"
    if [ -d "$npm_global_man" ]; then
        build_path "$npm_global_man" "$MANPATH"
        # The terminating colon is intentional! See manpath(1) for details.
        # shellcheck disable=SC2154
        export MANPATH="$build_path:"
    fi
    unset npm_global_man npm_global_root
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
