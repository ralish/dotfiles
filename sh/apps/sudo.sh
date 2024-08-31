# shellcheck shell=sh

# sudo configuration
if df_app_load 'sudo' 'command -v sudo > /dev/null'; then
    # Enables expansion of the subsequent command if it's an alias
    # See: https://askubuntu.com/a/22043/1602916
    alias sudo='sudo '
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
