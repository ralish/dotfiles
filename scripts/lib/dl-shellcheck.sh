#!/usr/bin/env bash

# pipefail is enabled in the sourcing script
# shellcheck disable=SC2312

# Application name
readonly APP_NAME="shellcheck"
# Local installation path
readonly APP_DST="$HOME/bin/shellcheck"
# Local installation directory
readonly APP_DST_DIR="$HOME/bin"
# Latest release information
readonly APP_LATEST_RELEASE='https://api.github.com/repos/koalaman/shellcheck/releases/latest'

# DESC: Download latest ShellCheck
# ARGS: None
# OUTS: None
# RETS: None
function dl_shellcheck() {
    check_binary curl fatal
    check_binary jq fatal
    check_binary xz fatal

    local current_ver
    if [[ -x $APP_DST ]]; then
        current_ver="$("$APP_DST" --version | grep -E '^version: .*' | grep -Eo '[0-9]+(\.[0-9]+){1,}')"
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

    local kernel_name kernel_name_raw
    kernel_name_raw="$(uname -s)"
    kernel_name="${kernel_name_raw,,}"
    if ! [[ $kernel_name =~ darwin|linux ]]; then
        script_exit "[$APP_NAME] Unsupported kernel: $kernel_name_raw" 1
    fi

    local machine_hw_name machine_hw_name_raw
    machine_hw_name_raw="$(uname -m)"
    machine_hw_name="$machine_hw_name_raw"
    case $machine_hw_name_raw in
        aarch64 | riscv64 | x86_64) ;;
        armv6*) machine_hw_name='armv6hf' ;;
        *)
            script_exit "[$APP_NAME] Unsupported machine hardware: $machine_hw_name_raw" 1
            ;;
    esac

    local latest_contains
    # Match on `.tar.xz` required due to existence of `.tar.gz` variant
    latest_contains="${kernel_name}.${machine_hw_name}.tar.xz"
    verbose_print "[$APP_NAME] Filtering for release containing: $latest_contains"

    local latest_url
    latest_url="$(echo "$metadata" | jq -Mr ".assets[] | select(.name | contains(\"$latest_contains\")) | .browser_download_url")"
    if [[ -z $latest_url ]]; then
        script_exit "[$APP_NAME] Unable to find release for kernel & machine hardware: $latest_contains" 1
    fi

    if [[ -n ${current_ver-} ]]; then
        pretty_print "[$APP_NAME] Updating v$current_ver to v$latest_ver ..."
    else
        pretty_print "[$APP_NAME] Installing v$latest_ver ..."
    fi
    if ! [[ -d $APP_DST_DIR ]]; then
        mkdir "$APP_DST_DIR"
    fi
    curl -sSL "$latest_url" | tar -xJ -f - -C "$APP_DST_DIR" --strip-components=1 --wildcards "*/$APP_NAME"
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
