# shellcheck shell=sh

# Trivy configuration
if df_app_load 'trivy' 'command -v trivy > /dev/null'; then
    # Opt-out of telemetry
    export TRIVY_DISABLE_TELEMETRY=1
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
