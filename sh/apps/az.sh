# shellcheck shell=sh

# Azure CLI configuration
if command -v az > /dev/null; then
    # Opt-out of telemetry
    export AZURE_CORE_COLLECT_TELEMETRY=false
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
