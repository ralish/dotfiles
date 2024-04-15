#!/usr/bin/env bash

# Initialize a SUSE VM with a configuration optimised for testing.

set -e

if [[ $UID -ne 0 ]]; then
    echo 'Must run as root!'
    exit 1
fi

suse_release="$(grep 'SUSE' /etc/os-release || true)"
if [[ -z $suse_release ]]; then
    echo 'This script is only for SUSE systems.'
    exit 1
fi

function zypper_install() {
    local pkg_name="$1"

    if ! zypper search -i "$pkg_name" > /dev/null; then
        return
    fi

    echo "[zypper] Installing $pkg_name ..."
    zypper install -y "$pkg_name"
    echo
}

echo '[zypper] Updating package indexes ...'
zypper refresh
echo

echo '[zypper] Installing package updates ...'
zypper update -y
echo

zypper_install openssh-server
zypper_install vim

echo '[zypper] Cleaning local repository ...'
zypper clean -a
echo

if [[ -f /etc/sudoers ]]; then
    if [[ -z $SUDO_USER ]]; then
        # shellcheck disable=SC2016
        echo '[sudo] Expected $SUDO_USER to not be empty or unset.'
        exit 1
    fi

    # shellcheck disable=SC2312
    if ! id -nG "$SUDO_USER" | grep -qw wheel; then
        echo '[sudo] Adding user to wheel group ...'
        sudo usermod -aG wheel "$SUDO_USER"

        echo '[sudo] You must logout for wheel group membership to take effect.'
        echo '       Access to sudo commands will be denied until completed.'
    fi

    echo '[sudo] Disabling password prompts ...'
    sed -i 's/^\(Defaults[[:blank:]]\+targetpw[[:blank:]]\+#.\+\)/#\1/' /etc/sudoers
    sed -i 's/^\(ALL[[:blank:]]\+ALL=(ALL)[[:blank:]]\+ALL[[:blank:]]\+#.\+\)/#\1/' /etc/sudoers
    sed -i 's/^#[[:blank:]]\+\(%wheel[[:blank:]]\+ALL=(ALL:ALL)[[:blank:]]\+NOPASSWD:[[:blank:]]\+ALL\)$/\1/' /etc/sudoers
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
