#!/usr/bin/env bash

# Source in common metadata functions
script_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=metadata/templates/common.sh
source "$script_dir/templates/common.sh"

if ! command -v ssh > /dev/null; then
    exit $DETECTION_NOT_AVAILABLE
fi

# Important paths
OPENSSH_DIR="$script_dir/../openssh/.ssh"
OPENSSH_CFG="$OPENSSH_DIR/config"
OPENSSH_INCLUDES="$OPENSSH_DIR/includes"
OPENSSH_TEMPLATES="$OPENSSH_DIR/templates"
OPENSSH_BANNER="$OPENSSH_TEMPLATES/banner"

# Check for a supported version
ssh_version=$(ssh -V 2>&1 | grep -Eo '^OpenSSH_[0-9]\.[0-9]' | cut -c 9-)
ssh_template=$(printf '%s/ssh_config.%s' "$OPENSSH_TEMPLATES" "${ssh_version//.}")
if ! [[ -f $ssh_template ]]; then
    printf 'Unsupported OpenSSH version: %s\n' "$ssh_version"
    exit $DETECTION_NO_LOGIC
fi

# Build our configuration
shopt -s nullglob
echo -n > "$OPENSSH_CFG"
chmod 0600 "$OPENSSH_CFG"
head -n -1 "$OPENSSH_BANNER" >> "$OPENSSH_CFG"
for include in "$OPENSSH_INCLUDES"/*; do
    head -n -1 "$include" >> "$OPENSSH_CFG"
    echo >> "$OPENSSH_CFG"
done
cat "$ssh_template" >> "$OPENSSH_CFG"

exit $DETECTION_SUCCESS

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
