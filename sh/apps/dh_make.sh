# shellcheck shell=sh

# dh_make configuration
if command -v dh_make > /dev/null; then
    # Name & email for Debian packaging tools
    export DEBFULLNAME='Samuel D. Leslie'
    export DEBEMAIL='sdl@nexiom.net'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
