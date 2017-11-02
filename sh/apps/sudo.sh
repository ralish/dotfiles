# shellcheck shell=sh

# sudo configuration
if command -v sudo > /dev/null; then
    # Enables expansion of the subsequent command if it's an alias
    # See: https://askubuntu.com/questions/22037/aliases-not-available-when-using-sudo
    alias sudo='sudo '
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
