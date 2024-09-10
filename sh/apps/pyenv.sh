# shellcheck shell=sh

# pyenv configuration
pyenv_root="${PYENV_ROOT:-${HOME}/.pyenv}"

if df_app_load 'pyenv' "[ -d \"$pyenv_root\" ]"; then
    export PYENV_ROOT="$pyenv_root"
    pyenv_bin="${pyenv_root}/bin"

    if [ -d "$pyenv_bin" ]; then
        # Add bin directory to PATH
        build_path "$pyenv_bin" "$PATH"
        # shellcheck disable=SC2154
        export PATH="$build_path"
    fi

    # Initialise pyenv
    if command -v pyenv > /dev/null; then
        # shellcheck disable=SC2312
        eval "$(pyenv init -)"

        # Initialise pyenv-virtualenv
        if [ -x "${pyenv_root}/plugins/pyenv-virtualenv/bin/pyenv-virtualenv" ]; then
            # shellcheck disable=SC2312
            eval "$(pyenv virtualenv-init -)"
        fi
    fi
fi

unset pyenv_root

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
