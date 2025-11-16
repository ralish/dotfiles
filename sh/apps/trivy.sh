# shellcheck shell=sh

# Trivy configuration
if df_app_load 'trivy' 'command -v trivy > /dev/null'; then
    # Opt-out of telemetry
    # https://trivy.dev/docs/latest/advanced/telemetry/
    export TRIVY_DISABLE_TELEMETRY=1

    # Enable shell completion
    if [ -n "$BASH" ]; then
        # shellcheck disable=SC2312,SC3001,SC3046,SC3051 source=/dev/null
        source <(trivy completion bash)
    elif [ -n "$ZSH_NAME" ]; then
        # shellcheck disable=SC2312,SC3001,SC3046,SC3051 source=/dev/null
        source <(trivy completion zsh)
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
