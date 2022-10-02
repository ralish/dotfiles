# shellcheck shell=sh

# pip configuration
if command -v pip > /dev/null ||
    command -v pip2 > /dev/null ||
    command -v pip3 > /dev/null; then
    # If pip binary isn't present add an alias to newest Python runtime pip
    if ! command -v pip > /dev/null; then
        if command -v pip3 > /dev/null; then
            alias pip='pip3'
        else
            alias pip='pip2'
        fi
    fi

    # Disable the pip version check if any Salt packages are installed. With
    # Salt we typically will be running an older pip version due to frequent
    # incompatible changes introduced upstream which Salt needs to handle.
    if command -v salt-call > /dev/null; then
        export PIP_DISABLE_PIP_VERSION_CHECK=true
    fi

    # Add local bin directory to PATH (for --user)
    build_path "$HOME/.local/bin" "$PATH"
    # shellcheck disable=SC2154
    export PATH="$build_path"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
