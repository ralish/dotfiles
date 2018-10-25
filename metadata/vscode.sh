#!/usr/bin/env bash

# Source in common metadata functions
script_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=metadata/templates/common.sh
source "$script_dir/templates/common.sh"

if ! command -v code > /dev/null; then
    exit $DETECTION_NOT_AVAILABLE
fi

exit $DETECTION_SUCCESS

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
