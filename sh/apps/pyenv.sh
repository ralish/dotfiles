# shellcheck shell=sh

# pyenv configuration
if [ -d "$HOME/.pyenv" ]; then
    export PYENV_ROOT="$HOME/.pyenv"

    if [ -d "$PYENV_ROOT/bin" ]; then
        # Add bin directory to PATH
        build_path "$PYENV_ROOT/bin" "$PATH"
        # shellcheck disable=SC2154
        export PATH="$build_path"
    fi

    # Initialise pyenv
    if command -v pyenv > /dev/null; then
        # shellcheck disable=SC2312
        eval "$(pyenv init -)"

        # Initialise pyenv-virtualenv
        if [ -x "$PYENV_ROOT/plugins/pyenv-virtualenv/bin/pyenv-virtualenv" ]; then
            # shellcheck disable=SC2312
            eval "$(pyenv virtualenv-init -)"
        fi
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
