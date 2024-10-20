#!/usr/bin/env bash

# pipefail is enabled in the sourcing script
# shellcheck disable=SC2312

# Application name
readonly APP_NAME="hadolint"
# Local installation path
readonly APP_DST="$HOME/bin/hadolint"
# Latest release information
readonly APP_LATEST_RELEASE='https://api.github.com/repos/hadolint/hadolint/releases/latest'

# DESC: Download latest Hadolint
# ARGS: None
# OUTS: None
# RETS: None
function dl_hadolint() {
    check_binary curl fatal
    check_binary jq fatal

    local current_ver
    if [[ -x $APP_DST ]]; then
        current_ver="$("$APP_DST" --version | grep -Eo '[0-9]+(\.[0-9]+){1,}')"
        verbose_print "[$APP_NAME] Existing version: v$current_ver"
    else
        verbose_print "[$APP_NAME] Found no existing binary."
    fi

    verbose_print "[$APP_NAME] Retrieving release info ..."
    local metadata latest_ver
    metadata="$(curl -s "$APP_LATEST_RELEASE")"
    latest_ver="$(echo "$metadata" | jq -r '.tag_name' | grep -Eo '[0-9]+(\.[0-9]+){1,}')"

    if [[ $latest_ver == "${current_ver-}" ]]; then
        pretty_print "[$APP_NAME] Latest version is installed: v$current_ver"
        exit 0
    fi

    local kernel_name
    kernel_name="$(uname -s)"
    if ! [[ $kernel_name =~ Darwin|Linux ]]; then
        script_exit "[$APP_NAME] Unsupported kernel: $kernel_name" 1
    fi

    local machine_hw_name machine_hw_name_raw
    machine_hw_name_raw="$(uname -m)"
    case $machine_hw_name_raw in
        aarch64)
            machine_hw_name='arm64'
            ;;
        x86_64)
            machine_hw_name="$machine_hw_name_raw"
            ;;
        *)
            script_exit "[$APP_NAME] Unsupported machine hardware: $machine_hw_name_raw" 1
            ;;
    esac

    local latest_contains
    latest_contains="${kernel_name}-${machine_hw_name}"
    verbose_print "[$APP_NAME] Filtering for release containing: $latest_contains"

    local latest_url
    latest_url="$(echo "$metadata" | jq -Mr ".assets[] | select(.name | endswith(\"$latest_contains\")) | .browser_download_url")"
    if [[ -z $latest_url ]]; then
        script_exit "[$APP_NAME] Unable to find release for kernel & machine hardware: $latest_contains" 1
    fi

    if [[ -n ${current_ver-} ]]; then
        pretty_print "[$APP_NAME] Updating v$current_ver to v$latest_ver ..."
    else
        pretty_print "[$APP_NAME] Installing v$latest_ver ..."
    fi
    curl --create-dirs -sSL -o "$APP_DST" "$latest_url"
    chmod +x "$APP_DST"
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
