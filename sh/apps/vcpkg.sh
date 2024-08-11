# shellcheck shell=sh

# vcpkg configuration
if command -v vcpkg > /dev/null; then
    # Opt-out of telemetry
    export VCPKG_DISABLE_METRICS=true
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
