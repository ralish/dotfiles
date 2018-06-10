# shellcheck shell=sh

# dotnet configuration
if command -v dotnet > /dev/null; then
    # Opt-out of telemetry
    export DOTNET_CLI_TELEMETRY_OPTOUT=true
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
