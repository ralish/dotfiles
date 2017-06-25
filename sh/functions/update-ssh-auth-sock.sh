# shellcheck shell=sh

# When reattaching to a screen or tmux session the SSH_AUTH_SOCK environment
# variable in existing shells will typically be incorrect. This is because the
# environment variable will be pointing to the SSH agent socket at the time
# each shell was initially created. If we're reattaching in a new SSH session
# then the SSH agent socket path will have changed.
#
# While tmux is smart enough to update the environment variable in new shells
# when its update-environment option is correctly configured, it can't update
# the variable in existing shells. The screen multiplexer won't update at all.
#
# This function helps to handle this situation by updating the SSH_AUTH_SOCK
# environment variable to a hopefully sane value. If it detects we're running
# inside a screen session it will also update screen's environment so that
# future shells inherit the correct SSH agent socket path.
#
# Note that we do not (can not?) update the SSH_AUTH_SOCK environment variable
# for already spawned shells outside of the one we're currently executing in.

#shellcheck disable=SC2039
update-ssh-auth-sock() {
    ssh_current_agent="$SSH_AUTH_SOCK"

    if [ -n "$TMUX" ]; then
        eval "$(tmux show-environment -s | grep -E '^SSH_AUTH_SOCK=')"
    elif [ -n "$STY" ]; then
        uid="$(id -u)"
        ssh_agents="$(find /tmp -maxdepth 2 \
                                -name 'agent.*' \
                                -type s \
                                -uid "$uid" \
                                -printf '%T+ %p\n' 2> /dev/null)"
        ssh_latest_agent="$(echo "$ssh_agents" | sort -n -r \
                                               | head -n 1 \
                                               | cut -d' ' -f2)"

        if [ -n "$ssh_latest_agent" ]; then
            screen setenv SSH_AUTH_SOCK "$ssh_latest_agent"
            export SSH_AUTH_SOCK="$ssh_latest_agent"
        else
            screen unsetenv SSH_AUTH_SOCK
            unset SSH_AUTH_SOCK
        fi
    else
        echo 'Error: We do not appear to be running under screen or tmux.'
        unset ssh_current_agent
        return
    fi

    if [ "$SSH_AUTH_SOCK" != "$ssh_current_agent" ]; then
        if [ -n "$SSH_AUTH_SOCK" ]; then
            echo "Updated \$SSH_AUTH_SOCK to: $SSH_AUTH_SOCK"
        elif [ -n "$ssh_current_agent" ]; then
            # shellcheck disable=SC2016
            echo 'Removed $SSH_AUTH_SOCK as unable to find an SSH agent.'
        fi
    else
        # shellcheck disable=SC2016
        echo '$SSH_AUTH_SOCK is unchanged.'
    fi

    unset ssh_agents ssh_current_agent ssh_latest_agent uid
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
