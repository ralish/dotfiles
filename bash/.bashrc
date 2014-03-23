# If we're not running interactively then bail out
[ -z "$PS1" ] && return

# Path to our common shell configuration
SHCFG="$HOME/dotfiles/sh/common.sh"

# Don't insert lines with a space or duplicates into history
HISTCONTROL=ignoreboth

# Set the maximum number of commands to retain in the history
HISTSIZE=1000

# Set the maximum number of lines to retain in the history
HISTFILESIZE=2000

# Autocorrect typos when changing path with cd
shopt -s cdspell

# Update the window size after every command
shopt -s checkwinsize

# Try and save multi-line commands as a single entry
shopt -s cmdhist

# Try to autocorrect typos during directory completion
shopt -s dirspell

# Append to the history file instead of overwriting
shopt -s histappend

# Enable support for wildcard globbing via **
shopt -s globstar

# Make use of lesspipe if present for handling non-text input
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Default to using a color prompt for certain terminal types
case "$TERM" in
	xterm-color) color_prompt=yes;;
esac

# Force usage of a color prompt irrespective of terminal type
force_color_prompt=yes

# If we elected to force a color prompt check we can support it
if [ -n "$force_color_prompt" ]; then
	if [ -x /usr/bin/tput ] && tput setaf 1 >& /dev/null; then
		color_prompt=yes
	else
		color_prompt=
	fi
fi

# Configure our prompt optionally with color and git support
if [ "$color_prompt" = yes ]; then
	if [[ -f /etc/bash_completion.d/git-prompt ]]; then
		PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w$(__git_ps1)\[\033[00m\]\$ '
	else
		PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
	fi
elif [[ -f /etc/bash_completion.d/git-prompt ]]; then
	PS1='\u@\h:\w$(__git_ps1)\$ '
else
	PS1='\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm/rxvt set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
	PS1="\[\e]0;\u@\h: \w\a\]$PS1"
	;;
*)
	;;
esac

# Load our common shell configuration
source "$SHCFG"

# If we defined a custom aliases file then include it
if [ -f "$HOME/.bash_aliases" ]; then
	source "$HOME/.bash_aliases"
fi

# Enable much more powerful bash completion if available
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
	source /etc/bash_completion
fi

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet

