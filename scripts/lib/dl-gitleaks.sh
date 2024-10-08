#!/usr/bin/env bash

# Downloads or updates GitLeaks to the latest available version

# Local installation path
GL_DST="$HOME/bin/gitleaks"
# Local installation directory
GL_DST_DIR="$HOME/bin"
# Latest release information
GL_LATEST_RELEASE='https://api.github.com/repos/gitleaks/gitleaks/releases/latest'

# DESC: Update to latest Gitleaks
# ARGS: None
# OUTS: None
# RETS: None
function dl_gitleaks() {
    check_binary curl fatal
    check_binary jq fatal
    check_binary xz fatal

    local current_ver
    if [[ -x $GL_DST ]]; then
        current_ver="$("$GL_DST" version | grep -Eo '[0-9]+(\.[0-9]+){1,}')"
        verbose_print "[gitleaks] Existing version: v$current_ver"
    else
        verbose_print "[gitleaks] Found no existing binary."
    fi

    verbose_print "[gitleaks] Retrieving release info ..."
    local metadata latest_ver
    metadata="$(curl -s "$GL_LATEST_RELEASE")"
    latest_ver="$(echo "$metadata" | jq -r '.tag_name' | grep -Eo '[0-9]+(\.[0-9]+){1,}')"

    if [[ $latest_ver == "${current_ver-}" ]]; then
        pretty_print "[gitleaks] Latest version is installed: v$current_ver"
        exit 0
    fi

    local kernel_name kernel_name_raw
    kernel_name_raw="$(uname -s)"
    kernel_name="${kernel_name_raw,,}"
    if ! [[ $kernel_name =~ darwin|linux ]]; then
        script_exit "[gitleaks] Unsupported kernel: $kernel_name_raw" 1
    fi

    local machine_hw_name machine_hw_name_raw
    machine_hw_name_raw="$(uname -m)"
    case $machine_hw_name_raw in
        aarch64)
            machine_hw_name='arm64'
            ;;
        i386 | i686)
            machine_hw_name='x32'
            ;;
        x86_64)
            machine_hw_name='x64'
            ;;
        *)
            script_exit "[gitleaks] Unsupported machine hardware: $machine_hw_name_raw" 1
            ;;
    esac

    local latest_contains
    latest_contains="${kernel_name}_${machine_hw_name}"
    verbose_print "[gitleaks] Filtering for release containing: $latest_contains"

    local latest_url
    latest_url="$(echo "$metadata" | jq -Mr ".assets[] | select(.name | contains(\"$latest_contains\")) | .browser_download_url")"
    if [[ -z $latest_url ]]; then
        script_exit "[gitleaks] Unable to find release for kernel & machine hardware: $latest_contains" 1
    fi

    if [[ -n ${current_ver-} ]]; then
        pretty_print "[gitleaks] Updating v$current_ver to v$latest_ver ..."
    else
        pretty_print "[gitleaks] Installing v$latest_ver ..."
    fi
    if ! [[ -d $GL_DST_DIR ]]; then
        mkdir "$GL_DST_DIR"
    fi
    curl -sSL "$latest_url" | tar -x -z -C "$GL_DST_DIR" gitleaks
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
