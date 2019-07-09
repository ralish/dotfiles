#!/usr/bin/env bash

set -e

if [[ $UID -ne 0 ]]; then
    echo 'Must run as root!'
    exit 1
fi

lsb_release_id="$(lsb_release -s -i)"
if [[ $lsb_release_id != Ubuntu ]]; then
    echo 'This script is only for Ubuntu systems.'
    exit 1
fi

ubuntu_codename="$(lsb_release -s -c)"

echo '[apt] Switching to global mirror ... '
if ! [[ $ubuntu_codename == lucid ]]; then
    sed -i 's/\([a-z]\{2\}\.\)\?\(archive\.ubuntu\.com\)/\2/' /etc/apt/sources.list
else
    sed -i 's/\([a-z]\{2\}\.\)\?archive\.ubuntu\.com/old-releases.ubuntu.com/' /etc/apt/sources.list
    sed -i 's/security\.ubuntu\.com/old-releases.ubuntu.com/' /etc/apt/sources.list
fi
echo

echo '[apt] Updating package indexes ...'
apt-get update
echo

echo '[apt] Installing package updates ...'
apt-get -y dist-upgrade
echo

echo '[apt] Removing stale dependencies ...'
apt-get -y autoremove
echo

echo '[apt] Cleaning local repository ...'
apt-get clean
echo

echo '[apt] Removing package indexes ...'
rm -rf /var/lib/apt/lists
mkdir -p /var/lib/apt/lists/partial
echo

if [[ -f /etc/sudoers ]]; then
    echo '[sudo] Disabling password prompts ...'
    sed -i 's/^root[[:blank:]].*/root    ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
    sed -i 's/^%sudo[[:blank:]].*/%sudo   ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
    sed -i 's/^%admin[[:blank:]].*/%admin  ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
    echo
fi

if [[ -f /etc/update-manager/release-upgrades ]]; then
    echo '[update-manager] Disabling release upgrade prompts ...'
    sed -i 's/^Prompt=lts$/Prompt=never/' /etc/update-manager/release-upgrades
    echo
fi
