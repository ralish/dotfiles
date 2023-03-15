#!/usr/bin/env bash

# Source in common metadata functions
script_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=metadata/templates/common.sh
source "$script_dir/templates/common.sh"

if ! command -v ssh > /dev/null; then
    exit "$DETECTION_NOT_AVAILABLE"
fi

if ! command -v bc > /dev/null; then
    echo '[openssh] Unable to stow as bc was not found (required by our config).'
    exit "$DETECTION_NOT_AVAILABLE"
fi

# Important paths
OPENSSH_DIR="$script_dir/../openssh/.ssh"
OPENSSH_CFG="$OPENSSH_DIR/config"
OPENSSH_CFG_TMP="$OPENSSH_CFG.tmp"
OPENSSH_INCLUDES="$OPENSSH_DIR/includes"
OPENSSH_TEMPLATES="$OPENSSH_DIR/templates"
OPENSSH_BANNER="$OPENSSH_TEMPLATES/banner"

# Directives introduced in a given OpenSSH version
declare -A new_directives
new_directives['91']='RequiredRSASize'

# Check for a supported version
# shellcheck disable=SC2312
ssh_version=$(ssh -V 2>&1 | grep -Eo '^OpenSSH_[0-9]\.[0-9]' | cut -c 9-)
ssh_version_raw="${ssh_version//./}"
ssh_template=$(printf '%s/ssh_config.%s' "$OPENSSH_TEMPLATES" "$ssh_version_raw")
if ! [[ -f $ssh_template ]]; then
    printf 'Unsupported OpenSSH version: %s\n' "$ssh_version"
    exit "$DETECTION_NO_LOGIC"
fi

# Build our configuration
shopt -s nullglob
echo -n > "$OPENSSH_CFG_TMP"
chmod 0600 "$OPENSSH_CFG_TMP"
head -n -1 "$OPENSSH_BANNER" >> "$OPENSSH_CFG_TMP"
for include in "$OPENSSH_INCLUDES"/*; do
    head -n -1 "$include" >> "$OPENSSH_CFG_TMP"
    echo >> "$OPENSSH_CFG_TMP"
done
cat "$ssh_template" >> "$OPENSSH_CFG_TMP"

# Remove unsupported configuration directives
for directives_ver in "${!new_directives[@]}"; do
    ver_test="$(echo "$ssh_version_raw < $directives_ver" | bc -l)"
    if [[ $ver_test == 1 ]]; then
        # shellcheck disable=SC2068
        for directive in ${new_directives[@]}; do
            # TODO: Handle any previous comment and subsequent new-line
            # shellcheck disable=SC1087
            sed -i "/^[[:blank:]]*$directive[[:blank:]]\+[^[:blank:]]\+/d" "$OPENSSH_CFG_TMP"
        done
    fi
done

# Move the generated configuration file into place
mv "$OPENSSH_CFG_TMP" "$OPENSSH_CFG"

exit "$DETECTION_SUCCESS"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
