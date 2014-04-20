# Some general configuration common to most shells
# Should be compatible with at least: sh, bash, ksh, zsh

# Additional locations to prefix to our PATH
EXTRA_PATHS="~/bin"

# Our preferred text editors ordered by priority
EDITOR_PRIORITY="vim vi nano pico"

# Operating system and environment specific configurations
if [[ $(uname -s) == CYGWIN_NT-* ]]; then
	source "$HOME/dotfiles/sh/systems/cygwin.sh"
elif [ $(uname -s) = "Darwin" ]; then
	source "$HOME/dotfiles/sh/systems/osx.sh"
fi

# Customise our path
export PATH="$EXTRA_PATHS:$PATH"

# Figure out which editor to default to
for editor in $(echo $EDITOR_PRIORITY); do
	editor_path=$(command -v $editor)
	if [ -n "$editor_path" ]; then
		export EDITOR="$editor_path"
		export VISUAL="$editor_path"
		break
	fi
done

# If we defined a custom aliases file then include it
if [ -f "$HOME/dotfiles/sh/aliases.sh" ]; then
	source "$HOME/dotfiles/sh/aliases.sh"
fi

# Disable toggling flow control (use ixany to re-enable)
stty -ixon

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet
