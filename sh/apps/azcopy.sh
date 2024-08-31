# shellcheck shell=sh

# AzCopy configuration
if df_app_load 'AzCopy [azcopy]' 'command -v azcopy > /dev/null'; then
    # Disable logging to syslog
    export AZCOPY_DISABLE_SYSLOG=true
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
