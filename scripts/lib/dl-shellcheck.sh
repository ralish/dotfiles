#!/usr/bin/env bash

# Downloads or updates shellcheck to the latest available version

# Local installation path
SHCHK_DST="$HOME/bin/shellcheck"
# Local installation directory
SHCHK_DST_DIR="$HOME/bin"
# Latest release information
SHCHK_LATEST_RELEASE='https://api.github.com/repos/koalaman/shellcheck/releases/latest'

# DESC: Update to latest shellcheck
# ARGS: None
# OUTS: None
# RETS: None
function dl_shellcheck() {
    check_binary curl fatal
    check_binary jq fatal
    check_binary xz fatal

    local current_ver
    if [[ -x $SHCHK_DST ]]; then
        current_ver="$("$SHCHK_DST" --version | grep -E '^version: .*' | grep -Eo '[0-9]+(\.[0-9]+){1,}')"
        verbose_print "[shellcheck] Existing version: v$current_ver"
    else
        verbose_print "[shellcheck] Found no existing binary."
    fi

    verbose_print "[shellcheck] Retrieving release info ..."
    local metadata latest_ver
    metadata="$(curl -s "$SHCHK_LATEST_RELEASE")"
    latest_ver="$(echo "$metadata" | jq -r '.tag_name' | grep -Eo '[0-9]+(\.[0-9]+){1,}')"

    if [[ $latest_ver == "${current_ver-}" ]]; then
        pretty_print "[shellcheck] Latest version is installed: v$current_ver"
        exit 0
    fi

    local kernel_name kernel_name_raw
    kernel_name_raw="$(uname -s)"
    kernel_name="${kernel_name_raw,,}"
    if ! [[ $kernel_name =~ darwin|linux ]]; then
        script_exit "[shellcheck] Unsupported kernel: $kernel_name_raw" 1
    fi

    local machine_hw_name
    machine_hw_name="$(uname -m)"
    if ! [[ $machine_hw_name =~ aarch64|x86_64 ]]; then
        script_exit "[shellcheck] Unsupported machine hardware: $machine_hw_name" 1
    fi

    local latest_contains
    latest_contains="${kernel_name}.${machine_hw_name}"
    verbose_print "[shellcheck] Filtering for release containing: $latest_contains"

    local latest_url
    latest_url="$(echo "$metadata" | jq -Mr ".assets[] | select(.name | contains(\"$latest_contains\")) | .browser_download_url")"
    if [[ -z $latest_url ]]; then
        script_exit "[shellcheck] Unable to find release for kernel & machine hardware: $latest_contains" 1
    fi

    if [[ -n ${current_ver-} ]]; then
        pretty_print "[shellcheck] Updating v$current_ver to v$latest_ver ..."
    else
        pretty_print "[shellcheck] Installing v$latest_ver ..."
    fi
    if ! [[ -d $SHCHK_DST_DIR ]]; then
        mkdir "$SHCHK_DST_DIR"
    fi
    curl -sSL "$latest_url" | tar -x -J -C "$SHCHK_DST_DIR" --strip-components=1 --wildcards "*/shellcheck"
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
