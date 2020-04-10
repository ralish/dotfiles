# shellcheck shell=sh

# cruft configuration
if command -v cruft > /dev/null; then
    # Ignore several paths we almost never care about
    alias cruft='cruft --ignore "/dev /home /proc /run /snap /sys /tmp /usr/share/dotnet/sdk/NuGetFallbackFolder /var/cache/salt /var/cache/uptrack /var/lib/docker /var/lib/lxcfs"'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
