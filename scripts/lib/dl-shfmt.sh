#!/usr/bin/env bash

# Downloads or updates shfmt to the latest available version

# Local installation path
SHFMT_DST="$HOME/bin/shfmt"
# Latest release information
SHFMT_LATEST_RELEASE='https://api.github.com/repos/mvdan/sh/releases/latest'

# DESC: Update to latest shfmt
# ARGS: None
# OUTS: None
# RETS: None
function dl_shfmt() {
    check_binary curl fatal
    check_binary jq fatal

    local current_ver
    if [[ -x $SHFMT_DST ]]; then
        current_ver="$("$SHFMT_DST" --version | grep -Eo '[0-9]+(\.[0-9]+){1,}')"
        verbose_print "[shfmt] Existing version: v$current_ver"
    else
        verbose_print "[shfmt] Found no existing binary."
    fi

    verbose_print "[shfmt] Retrieving release info ..."
    local metadata latest_ver
    metadata="$(curl -s "$SHFMT_LATEST_RELEASE")"
    latest_ver="$(echo "$metadata" | jq -r '.tag_name' | grep -Eo '[0-9]+(\.[0-9]+){1,}')"

    if [[ $latest_ver == "${current_ver-}" ]]; then
        pretty_print "[shfmt] Latest version is installed: v$current_ver"
        exit 0
    fi

    local kernel_name kernel_name_raw
    kernel_name_raw="$(uname -s)"
    kernel_name="${kernel_name_raw,,}"
    if ! [[ $kernel_name =~ darwin|linux ]]; then
        script_exit "[shfmt] Unsupported kernel: $kernel_name_raw" 1
    fi

    local machine_hw_name machine_hw_name_raw
    machine_hw_name_raw="$(uname -m)"
    case $machine_hw_name_raw in
    i386 | i686)
        machine_hw_name='386'
        ;;
    x86_64)
        machine_hw_name='amd64'
        ;;
    *)
        script_exit "[shfmt] Unsupported machine hardware: $machine_hw_name_raw" 1
        ;;
    esac

    local latest_contains
    latest_contains="${kernel_name}_${machine_hw_name}"
    verbose_print "[shfmt] Filtering for release containing: $latest_contains"

    local latest_url
    latest_url="$(echo "$metadata" | jq -Mr ".assets[] | select(.name | contains(\"$latest_contains\")) | .browser_download_url")"
    if [[ -z $latest_url ]]; then
        script_exit "[shfmt] Unable to find release for kernel & machine hardware: $latest_contains" 1
    fi

    if [[ -n ${current_ver-} ]]; then
        pretty_print "[shfmt] Updating v$current_ver to v$latest_ver ..."
    else
        pretty_print "[shfmt] Installing v$latest_ver ..."
    fi
    curl --create-dirs -sSL -o "$SHFMT_DST" "$latest_url"
    chmod +x "$SHFMT_DST"
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
