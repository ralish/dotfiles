# If our homedir is encrypted with eCryptfs then don't unmount it on
# exit if any tmux sessions are running
if [ -d "$HOME/.ecryptfs" ]; then
    if $(tmux ls > /dev/null 2>&1); then
        rm -f "$HOME/.ecryptfs/auto-umount"
    else
        touch "$HOME/.ecryptfs/auto-umount"
    fi
fi

# Clear the console on exit if this is not a nested shell session
if [ "$SHLVL" = 1 ]; then
    [ -x /usr/bin/clear_console ] && /usr/bin/clear_console -q
fi

# vim: syntax=sh ts=4 sw=4 sts=4 et sr
