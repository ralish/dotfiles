#!/usr/bin/env ksh

# Initialize a OpenBSD VM with a configuration optimised for testing.

set -e

uid="$(id -u)"
if [[ $uid -ne 0 ]]; then
    echo 'Must run as root!'
    exit 1
fi

os_name="$(uname -s)"
if [[ $os_name != 'OpenBSD' ]]; then
    echo 'This script is only for OpenBSD systems.'
    exit 1
fi

echo '[syspatch] Checking for system patches ...'
syspatch_check="$(syspatch -c)"
if [[ -n $syspatch_check ]]; then
    echo
    echo '[syspatch] Installing system patches ...'
    syspatch
    echo
fi

echo '[syspatch] Listing installed system patches ...'
syspatch -l
echo

function pkg_add_install {
    local pkg_stem="$1"
    local pkg_flavour="$2"

    local pkg_test="$pkg_stem-*"
    if [[ -n $pkg_flavour ]]; then
        pkg_test="$pkg_test-$pkg_flavour"
    fi

    if pkg_info -q -e "$pkg_test"; then
        return
    fi

    # Friendly name to use in output
    local pkg_name_friendly="$pkg_stem"
    if [[ -n $pkg_flavour ]]; then
        pkg_name_friendly="$pkg_name_friendly ($pkg_flavour flavour)"
    fi

    # Attempt to find a matching package to install
    local pkg_regex="^$pkg_stem-[0-9]"
    if [[ -n $pkg_flavour ]]; then
        pkg_regex="$pkg_regex.*-$pkg_flavour$"
    fi

    local pkg_exists
    # shellcheck disable=SC2312
    pkg_exists="$(pkg_info -Q "$pkg_stem" | grep -E "$pkg_regex")"
    if [[ -z $pkg_exists ]]; then
        echo "[pkg_add] Unable to find package: $pkg_name_friendly"
        return
    fi

    # Name for requesting install
    local pkg_name_add="$pkg_stem"
    if [[ -n $pkg_flavour ]]; then
        pkg_name_add="$pkg_name_add--$pkg_flavour"
    fi

    echo "[pkg_add] Installing $pkg_name_friendly ..."
    pkg_add "$pkg_name_add"
    echo
}

echo '[pkg_add] Installing package updates ...'
pkg_add -I -u
echo

pkg_add_install bash
pkg_add_install vim no_x11

if command -v doas > /dev/null; then
    echo '[doas] Configuring ...'
    touch /etc/doas.conf
    chmod 0600 /etc/doas.conf
    cat << EOF > /etc/doas.conf
# Permit users in wheel group
permit keepenv nopass :wheel
EOF
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
