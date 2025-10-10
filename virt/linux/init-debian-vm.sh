#!/usr/bin/env bash

# Initialize a Debian or Ubuntu VM with a configuration optimised for testing.

set -e

if [[ $UID -ne 0 ]]; then
    echo 'Must run as root!'
    exit 1
fi

lsb_release_id="$(lsb_release -s -i 2> /dev/null)"
if ! [[ $lsb_release_id =~ Debian|Ubuntu ]]; then
    echo 'This script is only for Debian and Ubuntu systems.'
    exit 1
fi

function apt_install() {
    local pkg_name="$1"

    if dpkg -s "$pkg_name" > /dev/null 2>&1; then
        return
    fi

    # Check if the package is available to install. Simply using "apt-cache
    # show $pkg_name" is insufficient as it may return success if the package
    # is referenced by other packages but has no installation candidate.
    local pkg_exists
    pkg_exists="$(apt-cache search --names-only "^$pkg_name$")"
    if [[ -z $pkg_exists ]]; then
        echo "[apt] Unable to find package: $pkg_name"
        return
    fi

    echo "[apt] Installing $pkg_name ..."
    apt-get -y install "$pkg_name"
    echo
}

if [[ $lsb_release_id == 'Ubuntu' ]]; then
    echo '[apt] Switching to local mirror ... '
    ubuntu_release="$(lsb_release -s -r)"
    ubuntu_release_year="$(echo "$ubuntu_release" | grep -Eo '^[0-9]+')"
    if ((ubuntu_release_year >= 14)); then
        sed -i 's/http:\/\/\([a-z]\{2\}\.\)\?\(archive\.ubuntu\.com\)/http:\/\/au\.\2/' /etc/apt/sources.list
    else
        sed -i 's/http:\/\/\([a-z]\{2\}\.\)\?archive\.ubuntu\.com/http:\/\/old-releases.ubuntu.com/' /etc/apt/sources.list
        sed -i 's/http:\/\/security\.ubuntu\.com/http:\/\/old-releases.ubuntu.com/' /etc/apt/sources.list
    fi
fi

echo '[apt] Disabling automatic updates ...'
echo 'APT::Periodic::Enable "0";' > /etc/apt/apt.conf.d/05periodic

echo '[apt] Updating package indexes ...'
apt-get update
echo

echo '[apt] Installing package updates ...'
apt-get -y dist-upgrade
echo

apt_install debsums
apt_install openssh-server
apt_install sudo
apt_install vim

# Suppress any error as ancient APT versions do not have this command
echo '[apt] Removing stale dependencies ...'
apt-get -y autoremove || true
echo

echo '[apt] Cleaning local repository ...'
apt-get clean

echo '[apt] Removing package indexes ...'
rm -rf /var/lib/apt/lists
mkdir -p /var/lib/apt/lists/partial

if command -v snap > /dev/null; then
    # Suppress any error as only recent snapd versions have this command
    echo '[snap] Disabling automatic updates ...'
    snap refresh --hold || true
    echo

    echo '[snap] Updating all snaps ...'
    snap refresh
    echo
fi

if [[ -f /etc/sudoers ]]; then
    echo '[sudo] Disabling password prompts ...'
    sed -i 's/^root[[:blank:]].*/root    ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
    sed -i 's/^%sudo[[:blank:]].*/%sudo   ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
    sed -i 's/^%admin[[:blank:]].*/%admin  ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
fi

if [[ -f /etc/update-manager/release-upgrades ]]; then
    echo '[update-manager] Disabling release upgrade prompts ...'
    sed -i 's/^Prompt=lts$/Prompt=never/' /etc/update-manager/release-upgrades

    # Remove any cached release upgrade prompt
    if ((ubuntu_release_year >= 13)); then
        cat /dev/null > /var/lib/ubuntu-release-upgrader/release-upgrade-available
    elif [[ -d /var/lib/update-notifier ]]; then
        cat /dev/null > /var/lib/update-notifier/release-upgrade-available
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
