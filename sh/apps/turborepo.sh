# shellcheck shell=sh

# Turborepo configuration
if df_app_load 'turbo' 'command -v turbo > /dev/null'; then
    # Opt-out of telemetry
    export TURBO_TELEMETRY_DISABLED=1
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
