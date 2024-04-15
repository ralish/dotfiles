#!/usr/bin/env sh

# Initialize a NetBSD VM with a configuration optimised for testing.

set -e

uid="$(id -u)"
if [ "$uid" -ne 0 ]; then
    echo 'Must run as root!'
    exit 1
fi

os_name="$(uname -s)"
if [ "$os_name" != 'NetBSD' ]; then
    echo 'This script is only for NetBSD systems.'
    exit 1
fi

pkgin_install() {
    pkg_name="$1"

    if pkgin list | grep "$pkg_name" > /dev/null; then
        return
    fi

    echo "[pkgin] Installing $pkg_name ..."
    pkgin -y install "$pkg_name"
    echo
}

echo '[pkgin] Updating package repository ...'
pkgin update
echo

echo '[pkgin] Installing package updates ...'
pkgin -y upgrade
echo

pkgin_install bash
pkgin_install doas
pkgin_install vim

echo '[pkgin] Removing stale dependencies ...'
pkgin autoremove
echo

echo '[pkgin] Cleaning local repository ...'
pkgin clean
echo

if command -v doas > /dev/null; then
    echo '[doas] Configuring ...'
    touch /usr/pkg/etc/doas.conf
    chmod 0600 /usr/pkg/etc/doas.conf
    cat << EOF > /usr/pkg/etc/doas.conf
# Permit users in wheel group
permit keepenv nopass :wheel
EOF
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
