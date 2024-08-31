# shellcheck shell=sh

# nvm configuration

# Install directory
nvm_dir="$NVM_DIR"
if [ -z "$nvm_dir" ]; then
    if [ -n "$XDG_CONFIG_HOME" ]; then
        nvm_dir="${XDG_CONFIG_HOME}/nvm"
    else
        nvm_dir="${HOME}/.nvm"
    fi
fi

nvm_script="${nvm_dir}/nvm.sh"
if [ -s "$nvm_script" ]; then
    export NVM_DIR="$nvm_dir"

    # nvm is incompatible with NPM_CONFIG_PREFIX:
    # https://github.com/nvm-sh/nvm#compatibility-issues
    if [ -n "$NPM_CONFIG_PREFIX" ]; then
        unset NPM_CONFIG_PREFIX
    fi

    # shellcheck source=/dev/null
    . "$nvm_script"

    nvm_completion="${nvm_dir}/bash_completion"
    if [ -s "$nvm_completion" ]; then
        # shellcheck source=/dev/null
        . "$nvm_completion"
    fi
fi

unset nvm_dir nvm_script nvm_completion

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
