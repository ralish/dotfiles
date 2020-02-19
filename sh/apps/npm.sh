# shellcheck shell=sh

# npm configuration
if command -v npm > /dev/null; then
    npm_global_root="$(npm root -g)"
    npm_global_man="$npm_global_root/npm/man"

    # Add npm man pages to MANPATH
    if [ -d "$npm_global_man" ]; then
        build_path "$npm_global_man" "$MANPATH"
        # The terminating colon is intentional! See manpath(1) for details.
        # shellcheck disable=SC2154
        export MANPATH="$build_path:"
    fi

    unset npm_global_man npm_global_root

    npm_home_root="${NPM_CONFIG_PREFIX:-$HOME/.npm/node_modules}"
    npm_home_bin="$npm_home_root/bin"

    # Change default global packages path
    export NPM_CONFIG_PREFIX="$npm_home_root"

    # Add local bin directory to PATH
    build_path "$npm_home_bin" "$PATH"
    export PATH="$build_path"

    unset npm_home_root npm_home_bin
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
