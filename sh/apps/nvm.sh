# shellcheck shell=sh

# nvm configuration
nvm_dir="${NVM_DIR:-$HOME/.nvm}"
nvm_script="$nvm_dir/nvm.sh"
nvm_completion="$nvm_dir/bash_completion"

if [ -s "$nvm_script" ]; then
    export NVM_DIR="$nvm_dir"

    # nvm is incompatible with NPM_CONFIG_PREFIX:
    # https://github.com/nvm-sh/nvm#compatibility-issues
    if [ -n "$NPM_CONFIG_PREFIX" ]; then
        unset NPM_CONFIG_PREFIX
    fi

    # shellcheck source=/dev/null
    . "$nvm_script"

    if [ -s "$nvm_completion" ]; then
        # shellcheck source=/dev/null
        . "$nvm_script"
    fi
fi

unset nvm_dir nvm_script nvm_completion

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
