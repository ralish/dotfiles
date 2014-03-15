# Some general cnfiguration common to all shells
# Should be compatible with: sh, bash, ksh, zsh

# Additional locations to prefix to our PATH
EXTRA_PATHS="~/bin"

# Our preferred text editors ordered by priority
EDITOR_PRIORITY="vim vi nano pico"

# OS X configuration
if [ $(uname -s) = "Darwin" ]; then
	. ~/dotfiles/sh/osx.sh
fi

# Customise our path
export PATH="$EXTRA_PATHS:$PATH"

# Figure out which editor to default to
for editor in $EDITOR_PRIORITY; do
	editor_path=$(command -v $editor)
	if [ -n "$editor_path" ]; then
		export EDITOR="$editor_path"
		export VISUAL="$editor_path"
		break
	fi
done

# Nuke toggling flow control (ixany to re-enable)
stty -ixon

