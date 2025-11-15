# shellcheck shell=sh

# Gitleaks configuration
if df_app_load 'gitleaks' 'command -v gitleaks > /dev/null'; then
    # Enable shell completion
    if [ -n "$BASH" ]; then
        # shellcheck disable=SC2312,SC3001,SC3046,SC3051 source=/dev/null
        source <(gitleaks completion bash)
    elif [ -n "$ZSH_NAME" ]; then
        # shellcheck disable=SC2312,SC3001,SC3046,SC3051 source=/dev/null
        source <(gitleaks completion zsh)
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
