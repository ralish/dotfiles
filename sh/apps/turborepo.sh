# shellcheck shell=sh

# Turborepo configuration
if df_app_load 'turbo' 'command -v turbo > /dev/null'; then
    # Opt-out of telemetry
    # https://turborepo.com/docs/telemetry
    export TURBO_TELEMETRY_DISABLED=1

    # Enable shell completion
    #
    # Redirection of `stderr` is required to suppress the output of the
    # Turborepo version number.
    if [ -n "$BASH" ]; then
        # shellcheck disable=SC2312,SC3001,SC3046,SC3051 source=/dev/null
        source <(turbo completion bash 2> /dev/null)
    elif [ -n "$ZSH_NAME" ]; then
        # shellcheck disable=SC2312,SC3001,SC3046,SC3051 source=/dev/null
        source <(turbo completion zsh 2> /dev/null)
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
