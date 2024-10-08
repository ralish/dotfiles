#!/usr/bin/env bash

# Downloads or updates hadolint to the latest available version

# Local installation path
HADOLINT_DST="$HOME/bin/hadolint"
# Latest release information
HADOLINT_LATEST_RELEASE='https://api.github.com/repos/hadolint/hadolint/releases/latest'

# DESC: Update to latest hadolint
# ARGS: None
# OUTS: None
# RETS: None
function dl_hadolint() {
    check_binary curl fatal
    check_binary jq fatal

    local current_ver
    if [[ -x $HADOLINT_DST ]]; then
        current_ver="$("$HADOLINT_DST" --version | grep -Eo '[0-9]+(\.[0-9]+){1,}')"
        verbose_print "[hadolint] Existing version: v$current_ver"
    else
        verbose_print "[hadolint] Found no existing binary."
    fi

    verbose_print "[hadolint] Retrieving release info ..."
    local metadata latest_ver
    metadata="$(curl -s "$HADOLINT_LATEST_RELEASE")"
    latest_ver="$(echo "$metadata" | jq -r '.tag_name' | grep -Eo '[0-9]+(\.[0-9]+){1,}')"

    if [[ $latest_ver == "${current_ver-}" ]]; then
        pretty_print "[hadolint] Latest version is installed: v$current_ver"
        exit 0
    fi

    local kernel_name kernel_name_raw
    kernel_name_raw="$(uname -s)"
    kernel_name="${kernel_name_raw,,}"
    if ! [[ $kernel_name =~ darwin|linux ]]; then
        script_exit "[hadolint] Unsupported kernel: $kernel_name_raw" 1
    fi

    local machine_hw_name
    machine_hw_name="$(uname -m)"
    if ! [[ $machine_hw_name =~ aarch64|x86_64 ]]; then
        script_exit "[hadolint] Unsupported machine hardware: $machine_hw_name" 1
    fi

    local latest_contains
    latest_contains="${kernel_name^}-${machine_hw_name}"
    verbose_print "[hadolint] Filtering for release containing: $latest_contains"

    local latest_url
    latest_url="$(echo "$metadata" | jq -Mr ".assets[] | select(.name | endswith(\"$latest_contains\")) | .browser_download_url")"
    if [[ -z $latest_url ]]; then
        script_exit "[hadolint] Unable to find release for kernel & machine hardware: $latest_contains" 1
    fi

    if [[ -n ${current_ver-} ]]; then
        pretty_print "[hadolint] Updating v$current_ver to v$latest_ver ..."
    else
        pretty_print "[hadolint] Installing v$latest_ver ..."
    fi
    curl --create-dirs -sSL -o "$HADOLINT_DST" "$latest_url"
    chmod +x "$HADOLINT_DST"
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
