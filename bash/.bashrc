# If we're not running interactively then bail out
[[ -z $PS1 ]] && return

# Path to our common shell configuration
SHCFG="$HOME/dotfiles/sh/common.sh"

# Don't insert duplicates or lines with a leading space into the history
HISTCONTROL=ignoreboth

# Maximum number of commands to retain in the history
HISTSIZE=1000

# Maximum number of lines to retain in the history
HISTFILESIZE=2000

# Autocorrect typos when changing path with "cd"
shopt -s cdspell

# Update the window size after every command
shopt -s checkwinsize

# Try and save multi-line commands as a single entry
shopt -s cmdhist

# Try to autocorrect typos during directory completion
shopt -s dirspell

# Append to the history file instead of overwriting
shopt -s histappend

# Enable support for wildcard globbing via "**"
shopt -s globstar

# Make use of lesspipe if present for handling non-text input
[[ -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

# Default to using a colour prompt for certain terminal types
case "$TERM" in
    xterm-color) colour_prompt=yes;;
esac

# Force usage of a colour prompt irrespective of terminal type
force_colour_prompt=yes

# If we elected to force a colour prompt check we can support it
if [[ -n $force_colour_prompt ]]; then
    if [[ -x /usr/bin/tput ]] && tput setaf 1 >& /dev/null; then
        colour_prompt=yes
    fi
fi

# Configure prompt with colour support if requested & Git support if available
if [[ -n $colour_prompt ]]; then
    if [[ -f /etc/bash_completion.d/git-prompt || -f /etc/bash_completion.d/git ]]; then
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w$(__git_ps1)\[\033[00m\]\$ '
    else
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    fi
elif [[ -f /etc/bash_completion.d/git-prompt || -f /etc/bash_completion.d/git ]]; then
    PS1='\u@\h:\w$(__git_ps1)\$ '
else
    PS1='\u@\h:\w\$ '
fi
unset colour_prompt force_colour_prompt

# Set the window title to "user@host:dir" if this is an xterm or rxvt terminal
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;\u@\h: \w\a\]$PS1"
    ;;
esac

# Load our common shell configuration
source "$SHCFG"

# Enable more powerful bash completion if available
if [[ -f /etc/bash_completion ]] && ! shopt -oq posix; then
    source /etc/bash_completion
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
