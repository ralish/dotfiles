#!/usr/bin/env bash

# Source in common metadata functions
script_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=metadata/templates/common.sh
source "$script_dir/templates/common.sh"

if ! command -v less > /dev/null; then
    exit "$DETECTION_NOT_AVAILABLE"
fi

# less can read lesskey source from version 582 (deprecating lesskey)
# shellcheck disable=SC2312
less_version=$(less -V | grep -Eo '^less \S+' | grep -Eo '[0-9]+')
if ((less_version >= 582)); then
    exit "$DETECTION_SUCCESS"
fi

if ! command -v lesskey > /dev/null; then
    exit "$DETECTION_NOT_AVAILABLE"
fi

# Path to the lesskey configuration file
LESSKEY="$script_dir/../less/.lesskey"

# Generate the binary configuration file
# shellcheck disable=SC2312
lesskey -- <(cat "$LESSKEY")

# Remove any existing less history file
rm -f "$HOME/.lesshst"

exit "$DETECTION_SUCCESS"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
