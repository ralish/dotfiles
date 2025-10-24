# shellcheck shell=sh

# WSL shell configuration

# Setup SSH agent forwarding
SETUP_SSH_AUTH_SOCK=true

# -----------------------------------------------------------------------------

df_log 'Loading environment configuration: WSL'

# Helper function to setup SSH agent forwarding
# Based on: https://github.com/rupor-github/wsl-ssh-agent#wsl-2-compatibility
#
# We need to retrieve the Linux equivalent path of the npiperelay executable
# which exists on the Windows host. Two methods of doing so are implemented.
#
# Approach #1: WSLENV (preferred)
# Requires the WSL_NPIPERELAY_PATH environment variable on the Windows system
# be set to the absolute path to npiperelay.exe. Also, the WSLENV environment
# variable must be set to pass it through to WSL when invoked from Win32, and
# perform the path translation. For example: "WSLENV=WSL_NPIPERELAY_PATH/pu".
#
# This method has the advantage of requiring no additional support utilities in
# the distribution, as the path is resolved on the host and passed in by WSL.
# It's also faster as no utilities need to be run to resolve the path on each
# spawned shell. However, WSLENV support is only available since Windows 10,
# Version 1803. If you aren't running this though, you need to upgrade!
#
# Approach #2: wslpath & wslvar (fallback)
# Uses the wslvar utility to retrieve the APPDATA environment variable from the
# Win32 environment, and the wslpath utility to translate it to the Linux path.
# The final path is assumed to be: "$APPDATA/Go/bin/npiperelay.exe".
#
# This can work on any WSL release, but requires the relevant WSL utilities to
# be available (wslpath & wslvar). The latter is no longer included by default
# since Ubuntu 22.04, requiring extra steps to install it. It's also slower as
# multiple programs have to be executed on each spawned shell.
wsl_setup_ssh_auth_sock() {
    if [ -n "${SSH_AUTH_SOCK}" ]; then
        #echo "[WSL] Skipping SSH_AUTH_SOCK setup as it's already set."
        return
    fi

    deps='socat ss'
    for dep in $deps; do
        if ! command -v "$dep" > /dev/null; then
            echo "[WSL] Skipping SSH_AUTH_SOCK setup as missing dependency: $dep"
            return
        fi
    done

    # Approach #1: WSLENV
    if [ -n "$WSL_NPIPERELAY_PATH" ]; then
        npiperelay="$WSL_NPIPERELAY_PATH"
        if ! [ -x "$npiperelay" ] || [ -d "$npiperelay" ]; then
            echo "[WSL] Skipping SSH_AUTH_SOCK setup as WSL_NPIPERELAY_PATH does not resolve to an executable file: $npiperelay"
            return
        fi
    else
        # Approach #2: wslpath & wslvar
        deps='wslpath wslvar'
        for dep in $deps; do
            if ! command -v "$dep" > /dev/null; then
                echo "[WSL] Skipping SSH_AUTH_SOCK setup as dependency is missing for resolving path to npiperelay: $dep"
                return
            fi
        done

        # The PATH setup for wslvar is required due to LP #1877016
        # https://bugs.launchpad.net/ubuntu/+source/wslu/+bug/1877016
        # shellcheck disable=SC2312
        winappdata="$(wslpath "$(PATH=$PATH:/mnt/c/Windows/System32 wslvar --sys APPDATA)")"
        npiperelay="$winappdata/Go/bin/npiperelay.exe"
        if ! [ -x "$npiperelay" ]; then
            echo "[WSL] Skipping SSH_AUTH_SOCK setup as resolved path to npiperelay is not an executable: $npiperelay"
            return
        fi
    fi

    SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    if [ -e "$SSH_AUTH_SOCK" ]; then
        if ! [ -S "$SSH_AUTH_SOCK" ]; then
            echo '[WSL] Skipping SSH_AUTH_SOCK setup as file is not a socket.'
            return
        fi

        # Socket appears to be alive
        if socat OPEN:/dev/null UNIX-CONNECT:/home/sdl/.ssh/agent.sock 2> /dev/null; then
            export SSH_AUTH_SOCK
            return
        fi

        # Socket exists but is dead. Most likely the previous socat process
        # didn't exit cleanly. Remove it and continue to setup a new socket.
        rm "$SSH_AUTH_SOCK"
    fi

    rm -f "$SSH_AUTH_SOCK"
    (
        setsid socat \
            UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
            EXEC:"$npiperelay -ei -s //./pipe/openssh-ssh-agent",nofork &
    ) > /dev/null 2>&1
    export SSH_AUTH_SOCK
}

# Setup SSH agent forwarding if requested
if [ -n "${SETUP_SSH_AUTH_SOCK}" ]; then
    wsl_setup_ssh_auth_sock
fi
unset SETUP_SSH_AUTH_SOCK wsl_setup_ssh_auth_sock

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
