# shellcheck shell=sh

# GCC configuration
if command -v gcc > /dev/null; then
    # Enable colour output
    export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
