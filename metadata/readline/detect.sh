#!/usr/bin/env bash

if [ "${kernel_name#*Linux}" != "$kernel_name" ]; then
    if ! dpkg --get-selections | egrep '^libreadline' > /dev/null; then
        exit 1
    fi
elif [ "${kernel_name#*CYGWIN_NT}" != "$kernel_name" ]; then
    if ! cygcheck -c -d | egrep '^libreadline' > /dev/null; then
        exit 1
    fi
else
    exit 2
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
