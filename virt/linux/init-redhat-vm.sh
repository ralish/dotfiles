#!/usr/bin/env bash

# Initialize a RHEL or Fedora VM with a configuration optimised for testing.

set -e

if [[ $UID -ne 0 ]]; then
    echo 'Must run as root!'
    exit 1
fi

rh_release="$(grep -E '^(Red Hat|Fedora)' /etc/redhat-release || true)"
if [[ -z $rh_release ]]; then
    echo 'This script is only for Red Hat and Fedora systems.'
    exit 1
fi

function yum_install() {
    local pkg_name="$1"

    # shellcheck disable=SC2312
    if ! rpm -qa | grep "$pkg_name" > /dev/null; then
        return
    fi

    echo "[yum] Installing $pkg_name ..."
    yum -y install "$pkg_name"
    echo
}

echo '[yum] Updating package indexes ...'
set +e
yum check-update
yum_rc="$?"
set -e
if [[ $yum_rc -eq 100 ]]; then
    echo
    echo '[yum] Installing package updates ...'
    yum -y upgrade
elif [[ $yum_rc -ne 0 ]]; then
    echo "[yum] check-update rc: $yum_rc"
    exit 1
fi
echo

yum_install openssh-server
yum_install vim-minimal

echo '[yum] Removing stale dependencies ...'
yum -y autoremove
echo

echo '[yum] Cleaning local repository ...'
yum clean all
echo

if [[ -f /etc/sudoers ]]; then
    echo '[sudo] Disabling password prompts ...'
    sed -i 's/^root[[:blank:]]\+ALL=(ALL)[[:blank:]]\+ALL$/root\tALL=(ALL)\tNOPASSWD: ALL/' /etc/sudoers
    sed -i 's/^\(%wheel[[:blank:]]\+ALL=(ALL)[[:blank:]]\+ALL\)$/#\1/' /etc/sudoers
    sed -i 's/^# \(%wheel[[:blank:]]\+ALL=(ALL)[[:blank:]]\+NOPASSWD: ALL\)$/\1/' /etc/sudoers
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
