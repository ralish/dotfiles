# shellcheck shell=sh

# pip configuration
if df_app_load 'pip' 'command -v pip > /dev/null ||
                      command -v pip2 > /dev/null ||
                      command -v pip3 > /dev/null'; then
    # If pip (without numeric suffix) isn't present alias it to the pip for the
    # latest available Python runtime.
    if ! command -v pip > /dev/null; then
        if command -v pip3 > /dev/null; then
            alias pip='pip3'
        else
            alias pip='pip2'
        fi
    fi

    # Add local bin directory to PATH (for --user)
    build_path "${HOME}/.local/bin" "$PATH"
    # shellcheck disable=SC2154
    export PATH="$build_path"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
