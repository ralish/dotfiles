# Some general configuration common to most shells
# Should be compatible with at least: sh, bash, ksh, zsh

# Additional locations to prefix to our PATH
EXTRA_PATHS=''

# Our preferred text editors ordered by priority
EDITOR_PRIORITY='vim vi nano pico'

# Preserve our original PATH for use in some later munging
original_path="$PATH"

# Quick and dirty function to help manage adding to the PATH
function path_add_prefix() {
    if [ $# -eq 2 ]; then
        if [ -n "$1" -a -n "$2" ]; then
            echo "$1:$2"
        else
            echo "$1$2"
        fi
    else
        echo 'Called path_add_prefix with an invalid number of parameters!'
    fi
}

# Add any extra paths before we run the system specific stuff
path_changes_general=$(path_add_prefix "$EXTRA_PATHS" "$path_changes_general")

# If a bin directory exists in our home directory then add it
if [ -d "$HOME/bin" ]; then
    path_changes_general=$(path_add_prefix "$HOME/bin" "$path_changes_general")
fi

# Update the PATH with any changes we've recorded
if [ -n "$path_changes_general" ]; then
    export PATH="$path_changes_general:$PATH"
fi

# Operating system and environment specific configurations
if [[ $(uname -s) == CYGWIN_NT-* ]]; then
    source "$HOME/dotfiles/sh/systems/cygwin.sh"
elif [ $(uname -s) = 'Darwin' ]; then
    source "$HOME/dotfiles/sh/systems/osx.sh"
fi

# Construct the final PATH with both the general and system changes
if [ -n "$path_changes_system" ]; then
    path_changes="$path_changes_system"
fi
if [ -n "$path_changes_general" ]; then
    path_changes=$(path_add_prefix "$path_changes_general" "$path_changes")
fi
if [ -n "$path_changes" ]; then
    export PATH="$path_changes:$original_path"
fi

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
