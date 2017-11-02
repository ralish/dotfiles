# shellcheck shell=sh

# cruft configuration
if command -v cruft > /dev/null; then
    # Ignore several paths we almost never care about
    alias cruft='cruft --ignore "/dev /home /sys /tmp /var/cache/salt /var/cache/uptrack"'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
