# shellcheck shell=sh

# PowerShell configuration
if command -v pwsh > /dev/null; then
    # Opt-out of telemetry
    export POWERSHELL_TELEMETRY_OPTOUT=true
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
