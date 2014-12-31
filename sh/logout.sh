# If our homedir is encrypted with eCryptfs then don't unmount it on exit if
# any tmux sessions are running. This is more difficult than it should be as
# eCryptfs doesn't decrement the active sessions counter on the shared memory
# device if the auto-umount file isn't present. Yes, this is entirely stupid.
if [ -d "$HOME/.ecryptfs" ]; then
    if $(tmux ls > /dev/null 2>&1); then
        rm -f "$HOME/.ecryptfs/auto-umount"
        count=$(cat /dev/shm/ecryptfs-$USER-Private)
        let count--
        echo $count > /dev/shm/ecryptfs-$USER-Private
    else
        touch "$HOME/.ecryptfs/auto-umount"
    fi
fi

# Clear the console on exit if this is not a nested shell session
if [ "$SHLVL" = 1 ]; then
    [ -x /usr/bin/clear_console ] && /usr/bin/clear_console -q
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
