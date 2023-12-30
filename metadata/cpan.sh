#!/usr/bin/env bash

# Source in common metadata functions
script_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=metadata/templates/common.sh
source "$script_dir/templates/common.sh"

if ! command -v cpan > /dev/null; then
    exit "$DETECTION_NOT_AVAILABLE"
fi

cpan_dir="$script_dir/../cpan/.cpan/CPAN"
if ! [[ -e "$cpan_dir/MyConfig.pm" ]]; then
    cp "$cpan_dir/MyConfig-Nix.pm" "$cpan_dir/MyConfig.pm"
fi

exit "$DETECTION_SUCCESS"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
