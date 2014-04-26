# When reattaching to a screen or tmux session the environment variables
# in child and newly created shells will be set to those at the time the
# session was initially created. There are some exceptions to this rule,
# for example, tmux's update-environment option. The primary use case
# for this option is to handle updating environment variables that are
# likely connection specific such as $SSH_AUTH_SOCK.
#
# While this usually works well, there are cases where it doesn't. For
# example, if a user has a long running attached screen/tmux session on
# PC1, attaches to the session on PC2 and subsequently disconnects, the
# $SSH_AUTH_SOCK variable will be pointing to the now defunct SSH agent
# socket that formerly belonged to the connection from PC2.
#
# This simple function will update the $SSH_AUTH_SOCK variable to point
# to the most recently created SSH agent socket for the effective user.
# If it detects we're running inside a screen/tmux session it will also
# update the multiplexer environment so that future shells inherit the
# correct environment variable.
#
# Note that we do not (can not?) update the shell environment variable
# for already spawned shells outside of the one we're executing in.

function ssh-fix-auth-sock {
	if $(command -v id 1> /dev/null); then
		uid=$(id -u)
	else
		echo "id command not found; exiting."
		exit 1
	fi

	ssh_agents=$(find /tmp -maxdepth 2 -type s -uid $uid -name 'agent.*' -printf '%T+ %p\n' 2> /dev/null)
	if [ -z "$ssh_agents" ]; then
		echo "Unable to locate any available SSH agents; exiting."
		exit 1
	else
		best_agent=$(echo $ssh_agents | sort -r | head -n 1 | cut -d' ' -f2)
		if [ $SSH_AUTH_SOCK != $best_agent ]; then
			export SSH_AUTH_SOCK=$best_agent
			if [ -n "$TMUX" ]; then
				tmux setenv SSH_AUTH_SOCK $best_agent
			fi
			if [ -n "$STY" ]; then
				screen setenv SSH_AUTH_SOCK $best_agent
			fi
			echo "Updated \$SSH_AUTH_SOCK to: $best_agent"
		else
			echo "\$SSH_AUTH_SOCK already set to best SSH agent."
		fi
	fi
}

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet
