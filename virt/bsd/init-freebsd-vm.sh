#!/usr/bin/env sh

# Initialize a FreeBSD VM with a configuration optimised for testing.

set -e

uid="$(id -u)"
if [ "$uid" -ne 0 ]; then
    echo 'Must run as root!'
    exit 1
fi

os_name="$(uname -s)"
if [ "$os_name" != 'FreeBSD' ]; then
    echo 'This script is only for FreeBSD systems.'
    exit 1
fi

echo '[freebsd-update] Configuring ...'
sed -i '' 's/^# BackupKernel yes$/BackupKernel no/' /etc/freebsd-update.conf

echo '[freebsd-update] Fetching available updates ...'
PAGER='cat' freebsd-update fetch
set +e
freebsd-update updatesready > /dev/null
freebsd_update_rc="$?"
set -e
if [ "$freebsd_update_rc" -eq 0 ]; then
    echo
    echo '[freebsd-update] Installing system updates ...'
    freebsd-update install
elif [ "$freebsd_update_rc" -ne 2 ]; then
    echo "[freebsd-update] fetch rc: $freebsd_update_rc"
    exit 1
fi
echo

pkg_install() {
    pkg_name="$1"

    if pkg info -e "$pkg_name"; then
        return
    fi

    echo "[pkg] Installing $pkg_name ..."
    pkg install -y "$pkg_name"
    echo
}

if ! pkg -N > /dev/null 2>&1; then
    echo '[pkg] Bootstraping pkg tool ...'
    pkg bootstrap -y
    echo
fi

echo '[pkg] Updating package repository ...'
pkg update
echo

echo '[pkg] Installing package updates ...'
pkg upgrade -y
echo

pkg_install bash
pkg_install doas
pkg_install open-vm-tools-nox11
pkg_install vim

echo '[pkg] Removing stale dependencies ...'
pkg autoremove -y
echo

echo '[pkg] Cleaning local repository ...'
pkg clean -y
echo

if command -v doas > /dev/null; then
    echo '[doas] Configuring ...'
    touch /usr/local/etc/doas.conf
    chmod 0600 /usr/local/etc/doas.conf
    cat << EOF > /usr/local/etc/doas.conf
# Permit users in wheel group
permit keepenv nopass :wheel
EOF
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
