#!/usr/bin/env bash

# Source in common metadata functions
script_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=metadata/templates/common.sh
source "$script_dir/templates/common.sh"

if ! command -v ssh > /dev/null; then
    exit $DETECTION_NOT_AVAILABLE
fi

# Paths we need to know to build our configuration
OPENSSH_DIR="$script_dir/../openssh/.ssh"
OPENSSH_CFG="$OPENSSH_DIR/config"
TEMPLATE_DIR="$OPENSSH_DIR/templates"
CUSTOM_CFG="$TEMPLATE_DIR/ssh_config"

# Check for a supported version and build our config
ssh_version=$(ssh -V 2>&1)
if [[ $ssh_version =~ OpenSSH_5\.9 ]]; then
    head -n -1 "$CUSTOM_CFG" > "$OPENSSH_CFG"
    tail -n +4 "$TEMPLATE_DIR/ssh_config.59" >> "$OPENSSH_CFG"
elif [[ $ssh_version =~ OpenSSH_6\.6 ]]; then
    head -n -1 "$CUSTOM_CFG" > "$OPENSSH_CFG"
    tail -n +4 "$TEMPLATE_DIR/ssh_config.66" >> "$OPENSSH_CFG"
else
    echo "Unsupported OpenSSH version detected: $ssh_version"
    exit $DETECTION_NO_LOGIC
fi

exit $DETECTION_SUCCESS

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
