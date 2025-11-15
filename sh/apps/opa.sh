# shellcheck shell=sh

# OPA configuration
if df_app_load 'opa' 'command -v opa > /dev/null'; then
    # Enable shell completion
    if [ -n "$BASH" ]; then
        # shellcheck disable=SC2312,SC3001,SC3046,SC3051 source=/dev/null
        source <(opa completion bash)
    elif [ -n "$ZSH_NAME" ]; then
        # shellcheck disable=SC2312,SC3001,SC3046,SC3051 source=/dev/null
        source <(opa completion zsh)
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
