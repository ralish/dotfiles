# shellcheck shell=sh

# WSL shell configuration

# Setup SSH agent forwarding
SETUP_SSH_AUTH_SOCK=true

# -----------------------------------------------------------------------------

# Helper function to setup SSH agent forwarding
# Based on: https://github.com/rupor-github/wsl-ssh-agent#wsl-2-compatibility
wsl_setup_ssh_auth_sock() {
    if [ -n "${SSH_AUTH_SOCK}" ]; then
        #echo "[WSL] Skipping \$SSH_AUTH_SOCK setup as it's already set."
        return
    fi

    deps='socat ss wslpath wslvar'
    for dep in $deps; do
        if ! command -v "$dep" > /dev/null; then
            echo "[WSL] Skipping \$SSH_AUTH_SOCK setup as missing dependency: $dep"
            return
        fi
    done

    SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    if ss -l | grep -q "$SSH_AUTH_SOCK"; then
        export SSH_AUTH_SOCK
        return
    fi

    # The PATH setup for wslvar is required due to LP #1877016
    # https://bugs.launchpad.net/ubuntu/+source/wslu/+bug/1877016
    winappdata="$(wslpath "$(PATH=$PATH:/mnt/c/Windows/System32 wslvar --sys APPDATA)")"
    npiperelay="$winappdata/Go/bin/npiperelay.exe"
    if ! [ -x "$npiperelay" ]; then
        echo "[WSL] Skipping \$SSH_AUTH_SOCK setup as missing dependency: $npiperelay"
        unset SSH_AUTH_SOCK
        return
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
unset SETUP_SSH_AUTH_SOCK wsl_setup_ssh_auth_sock deps npiperelay winappdata

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
