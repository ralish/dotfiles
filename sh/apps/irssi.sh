# shellcheck shell=sh

# irssi configuration
if command -v irssi > /dev/null; then
    # Override a few environment variables when running irssi:
    # - Set a specific TERM as irssi doesn't like some newer ones we use
    # - Use our local time zone as the system we're running on may use UTC
    alias irssi='TERM="screen-256color" TZ=":/usr/share/zoneinfo/Australia/Melbourne" irssi'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
