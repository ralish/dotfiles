# Some general configuration common to most shells
# Should be compatible with at least: sh, bash, ksh, zsh

# Additional locations to prefix to our PATH
EXTRA_PATHS="~/bin"

# Our preferred text editors ordered by priority
EDITOR_PRIORITY="vim vi nano pico"

# Update our path immediately as some subsequent scripts may depend on it
export PATH="$EXTRA_PATHS:$PATH"

# Operating system and environment specific configurations
if [[ $(uname -s) == CYGWIN_NT-* ]]; then
    source "$HOME/dotfiles/sh/systems/cygwin.sh"
elif [ $(uname -s) = "Darwin" ]; then
    source "$HOME/dotfiles/sh/systems/osx.sh"
fi

# Pedantic fix to ensure our earlier extra paths are first in the path
extra_paths_escaped=$(echo $EXTRA_PATHS | sed 's/\//\\\//g')
PATH=$(echo $PATH | sed "s/$extra_paths_escaped:*//g")
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

# If we defined a custom functions file then include it
if [ -f "$HOME/dotfiles/sh/functions.sh" ]; then
    source "$HOME/dotfiles/sh/functions.sh"
fi

# Disable toggling flow control (use ixany to re-enable)
stty -ixon

# vim: syntax=sh ts=4 sw=4 sts=4 et sr
