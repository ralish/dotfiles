#!/usr/bin/env bash

# pipefail is enabled in the sourcing script
# shellcheck disable=SC2312

# Application name
readonly APP_NAME="yq"
# Local installation path
readonly APP_DST="$HOME/bin/yq"
# Local installation directory
readonly APP_DST_DIR="$HOME/bin"
# Latest release information
readonly APP_LATEST_RELEASE='https://api.github.com/repos/mikefarah/yq/releases/latest'

# DESC: Download latest yq
# ARGS: None
# OUTS: None
# RETS: None
function dl_yq() {
    check_binary curl fatal
    check_binary jq fatal
    check_binary xz fatal

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

    local kernel_name kernel_name_raw
    kernel_name_raw="$(uname -s)"
    kernel_name="${kernel_name_raw,,}"
    if ! [[ $kernel_name =~ darwin|freebsd|linux|netbsd|openbsd ]]; then
        script_exit "[$APP_NAME] Unsupported kernel: $kernel_name_raw" 1
    fi

    local machine_hw_name machine_hw_name_raw
    machine_hw_name_raw="$(uname -m)"
    case $machine_hw_name_raw in
        aarch64)
            machine_hw_name='arm64'
            ;;
        armv6* | armv7*)
            machine_hw_name='arm'
            ;;
        i686)
            machine_hw_name='386'
            ;;
        x86_64)
            machine_hw_name='amd64'
            ;;
        mips | mips64 | ppc64 | ppc64le | s390x)
            machine_hw_name="$machine_hw_name_raw"
            ;;
        *)
            script_exit "[$APP_NAME] Unsupported machine hardware: $machine_hw_name_raw" 1
            ;;
    esac

    local latest_contains latest_contains_tgz
    latest_contains="${kernel_name}_${machine_hw_name}"
    latest_contains_tgz="$latest_contains.tar.gz"
    verbose_print "[$APP_NAME] Filtering for release containing: $latest_contains"

    local latest_url
    latest_url="$(echo "$metadata" | jq -Mr ".assets[] | select(.name | contains(\"$latest_contains_tgz\")) | .browser_download_url")"
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
    curl -sSL "$latest_url" | tar -x -z -C "$APP_DST_DIR" --strip-components=1 --wildcards "./${APP_NAME}_${latest_contains}"
    mv "$APP_DST_DIR/${APP_NAME}_${latest_contains}" "$APP_DST"
    chmod +x "$APP_DST"
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
