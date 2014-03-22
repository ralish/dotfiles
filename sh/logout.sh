# If our homedir is encrypted with eCryptfs then don't unmount it on
# exit if any tmux sessions are running.
if [ -d $HOME/.ecryptfs ]; then
	if $(tmux ls 2>&1 >/dev/null); then
		rm -f $HOME/.ecryptfs/auto-umount
	else
		touch $HOME/.ecryptfs/auto-umount
	fi
fi

