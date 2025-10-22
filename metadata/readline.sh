#!/usr/bin/env bash

# Source in common metadata functions
script_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=metadata/templates/common.sh
source "$script_dir/templates/common.sh"

kernel_name=$(uname -s)
if [[ "${kernel_name#*Linux}" != "$kernel_name" ]]; then
    if command -v dpkg > /dev/null; then
        # shellcheck disable=SC2312
        if ! dpkg --get-selections | grep -E '^libreadline' > /dev/null; then
            exit "$DETECTION_NOT_AVAILABLE"
        fi
    elif command -v rpm > /dev/null; then
        if ! rpm -qa '^readline' > /dev/null; then
            exit "$DETECTION_NOT_AVAILABLE"
        fi
    else
        exit "$DETECTION_NO_LOGIC"
    fi
elif [[ "${kernel_name#*CYGWIN_NT}" != "$kernel_name" ]]; then
    # shellcheck disable=SC2312
    if ! cygcheck -c -d | grep -E '^libreadline' > /dev/null; then
        exit "$DETECTION_NOT_AVAILABLE"
    fi
elif [[ "${kernel_name#*OpenBSD}" != "$kernel_name" ]]; then
    # Readline is part of the base system
    exit "$DETECTION_SUCCESS"
else
    exit "$DETECTION_NO_LOGIC"
fi

exit "$DETECTION_SUCCESS"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
