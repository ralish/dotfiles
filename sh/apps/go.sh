# shellcheck shell=sh

# Go configuration
if df_app_load 'go' "[ -d \"/usr/local/go/bin\" ]"; then
    go_global="/usr/local/go"
    go_local="${HOME}/go"

    # Add global bin directory to PATH
    build_path "${go_global}/bin" "$PATH"
    # shellcheck disable=SC2154
    export PATH="$build_path"

    if [ -d "$go_local" ]; then
        # Add local bin directory to PATH
        build_path "${go_local}/bin" "$PATH"
        export PATH="$build_path"

        # Add local directory to GOPATH
        build_path "$go_local" "$GOPATH"
        export GOPATH="$build_path"
    fi

    unset go_local go_global
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
