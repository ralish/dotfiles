#!/usr/bin/env bash

# Initialize a Ubuntu VM with a configuration optimised for testing.

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

echo '[apt] Switching to local mirror ... '
ubuntu_release="$(lsb_release -s -r)"
ubuntu_release_year="${ubuntu_release:0:2}"
if ((ubuntu_release_year >= 14)); then
    sed -i 's/http:\/\/\([a-z]\{2\}\.\)\?\(archive\.ubuntu\.com\)/http:\/\/au\.\2/' /etc/apt/sources.list
else
    sed -i 's/http:\/\/\([a-z]\{2\}\.\)\?archive\.ubuntu\.com/http:\/\/old-releases.ubuntu.com/' /etc/apt/sources.list
    sed -i 's/http:\/\/security\.ubuntu\.com/http:\/\/old-releases.ubuntu.com/' /etc/apt/sources.list
fi

echo '[apt] Disabling automatic updates ...'
echo 'APT::Periodic::Enable "0";' > /etc/apt/apt.conf.d/05periodic

echo '[apt] Updating package indexes ...'
apt-get update
echo

echo '[apt] Installing package updates ...'
apt-get -y dist-upgrade
echo

# shellcheck disable=SC2312
if ! dpkg -l | grep debsums > /dev/null; then
    echo '[apt] Installing debsums ...'
    apt-get -y install debsums
    echo
fi

# shellcheck disable=SC2312
if ! dpkg -l | grep openssh-server > /dev/null; then
    echo '[apt] Installing OpenSSH server ...'
    apt-get -y install openssh-server
    echo
fi

# shellcheck disable=SC2312
if ! dpkg -l | grep vim > /dev/null; then
    echo '[apt] Installing Vim ...'
    apt-get -y install vim
    echo
fi

echo '[apt] Removing stale dependencies ...'
apt-get -y autoremove
echo

echo '[apt] Cleaning local repository ...'
apt-get clean

echo '[apt] Removing package indexes ...'
rm -rf /var/lib/apt/lists
mkdir -p /var/lib/apt/lists/partial

if command -v snap > /dev/null; then
    echo '[snap] Disabling automatic updates ...'
    snap refresh --hold
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
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
